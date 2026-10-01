module Api
  module V1
    # Ingest for food entries from Health Connect (via the Android app) or a
    # later quick-add. Accepts a single object or an array. Idempotent on
    # client_id: first POST wins.
    class NutritionController < ApplicationController
      def create
        records = Array.wrap(params[:_json].presence || params[:nutrition] || params)
        built = records.filter_map { |r| build_entry(r) }

        # First wins: drop records whose client_id is already stored so
        # retries are free and the history is never rewritten. (Existing
        # client_ids are filtered out BEFORE validation — a uniqueness check
        # on a re-sent record would otherwise 422 an idempotent retry.)
        fresh = built
          .uniq(&:client_id)
          .reject { |r| NutritionEntry.exists?(client_id: r.client_id) }
        valid, invalid = fresh.partition(&:valid?)
        invalid.each { |r| return render_validation(r) }

        if valid.any?
          now = Time.current
          NutritionEntry.insert_all!(
            valid.map { |r| r.attributes.slice(*INSERT_COLUMNS)
              .merge("created_at" => now, "updated_at" => now) }
          )
        end
        render json: { ingested: valid.size, received: records.size }, status: :created
      end

      def index
        hours = clamp_hours(params[:hours])
        render json: { nutrition: NutritionEntry.last_hours(hours).map { |r| nutrition_payload(r) } }
      end

      private

      INSERT_COLUMNS = %w[taken_at carbs_g calories_kcal meal_type source client_id].freeze

      def build_entry(record)
        record = record.permit(:taken_at, :carbs_g, :calories_kcal, :meal_type, :source, :client_id)
        taken = parse_time(record[:taken_at])
        return nil if taken.nil?

        # Zero means "not tracked" (e.g. a black coffee logged with kcal only):
        # coerce to nil so the > 0 validation can't reject the whole batch.
        carbs = record[:carbs_g].presence
        carbs = nil if carbs.to_f <= 0
        kcal = record[:calories_kcal].presence
        kcal = nil if kcal.to_f <= 0

        NutritionEntry.new(
          taken_at: taken,
          carbs_g: carbs,
          calories_kcal: kcal,
          meal_type: record[:meal_type],
          source: record[:source],
          client_id: record[:client_id]
        )
      rescue TypeError
        nil
      end

      def parse_time(value)
        return Time.at(value.to_i / 1000.0) if value.to_s.match?(/\A\d+\z/) # epoch ms
        Time.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def clamp_hours(raw)
        return 24 if raw.blank?
        [[raw.to_i, 1].max, 336].min
      end

      def nutrition_payload(entry)
        {
          id: entry.id,
          taken_at: entry.taken_at.iso8601,
          carbs_g: entry.carbs_g,
          calories_kcal: entry.calories_kcal,
          meal_type: entry.meal_type,
          source: entry.source,
          client_id: entry.client_id
        }
      end
    end
  end
end
