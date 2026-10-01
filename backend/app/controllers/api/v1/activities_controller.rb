module Api
  module V1
    # Ingest for Health Connect data uploaded by the Android app. Accepts a
    # single object or an array. Idempotent on client_id: first POST wins,
    # retries are free and never duplicate a row.
    class ActivitiesController < ApplicationController
      def create
        records = Array.wrap(params[:_json].presence || params[:activity] || params)
        built = records.filter_map { |r| build_session(r) }

        # First wins: drop records whose client_id is already stored so
        # retries are free and the history is never rewritten. (Existing
        # client_ids are filtered out BEFORE validation — a uniqueness check
        # on a re-sent record would otherwise 422 an idempotent retry.)
        fresh = built
          .uniq(&:client_id)
          .reject { |r| ActivitySession.exists?(client_id: r.client_id) }
        valid, invalid = fresh.partition(&:valid?)
        invalid.each { |r| return render_validation(r) }

        if valid.any?
          now = Time.current
          ActivitySession.insert_all!(
            valid.map { |r| r.attributes.slice(*INSERT_COLUMNS)
              .merge("created_at" => now, "updated_at" => now) }
          )
        end
        render json: { ingested: valid.size, received: records.size }, status: :created
      end

      def index
        hours = clamp_hours(params[:hours])
        render json: { activities: ActivitySession.last_hours(hours).map { |r| activity_payload(r) } }
      end

      private

      INSERT_COLUMNS = %w[started_at ended_at minutes calories_kcal avg_hr max_hr source client_id].freeze

      def build_session(record)
        record = record.permit(:started_at, :ended_at, :minutes, :calories_kcal,
                               :avg_hr, :max_hr, :source, :client_id)
        started = parse_time(record[:started_at])
        ended = parse_time(record[:ended_at])
        return nil if started.nil? || ended.nil?

        # Zero means "not tracked": coerce to nil so the > 0 validation
        # can't reject the whole batch on one empty field.
        kcal = record[:calories_kcal].presence
        kcal = nil if kcal.to_f <= 0
        avg = record[:avg_hr].presence
        avg = nil if avg.to_i <= 0
        max = record[:max_hr].presence
        max = nil if max.to_i <= 0

        ActivitySession.new(
          started_at: started,
          ended_at: ended,
          minutes: record[:minutes].presence || ((ended - started) / 60).round,
          calories_kcal: kcal,
          avg_hr: avg,
          max_hr: max,
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

      def activity_payload(session)
        {
          id: session.id,
          started_at: session.started_at.iso8601,
          ended_at: session.ended_at.iso8601,
          minutes: session.minutes,
          calories_kcal: session.calories_kcal,
          avg_hr: session.avg_hr,
          max_hr: session.max_hr,
          source: session.source,
          client_id: session.client_id
        }
      end
    end
  end
end
