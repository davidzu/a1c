module Api
  module V1
    # Nightscout-compatible ingest. xDrip+ uploads here.
    # Accepts a single entry or an array; only sgv/mbg entries are stored.
    class EntriesController < ApplicationController
      def create
        return render_error(code: "unauthorized", message: "Bad api-secret", status: :unauthorized) if secret_required? && !secret_valid?

        entries = Array.wrap(params[:_json].presence || params[:entry] || params)
        readings = entries.filter_map { |e| build_reading(e) }

        # First wins: a repeated reading (same time) is already stored, so
        # retries are free and the history is never rewritten.
        now = Time.current
        fresh = readings
          .uniq { |r| r.time }
          .reject { |r| GlucoseReading.exists?(time: r.time) }
        if fresh.any?
          GlucoseReading.insert_all!(
            fresh.map { |r| r.attributes.slice("sgv", "time", "direction", "device")
              .merge("created_at" => now, "updated_at" => now) }
          )
        end
        render json: { ingested: fresh.size, received: entries.size }, status: :created
      end

      private

      def build_reading(entry)
        entry = entry.permit(:type, :sgv, :mbg, :date, :dateString, :direction, :device)
        return nil unless %w[sgv mbg].include?(entry[:type].to_s)

        value = entry[:mbg].presence || entry[:sgv]
        time = parse_time(entry)
        return nil if value.to_i <= 0 || time.nil?

        GlucoseReading.new(sgv: value.to_i, time: time, direction: entry[:direction], device: entry[:device])
      rescue TypeError
        nil
      end

      def parse_time(entry)
        if entry[:date].present?
          Time.at(entry[:date].to_i / 1000.0)
        elsif entry[:dateString].present?
          Time.iso8601(entry[:dateString].to_s)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def secret_required?
        ingest_secret.present?
      end

      def secret_valid?
        provided = request.headers["api-secret"].to_s
        return false if provided.blank?

        provided == ingest_secret || provided == Digest::SHA1.hexdigest(ingest_secret)
      end

      def ingest_secret
        ENV["GLUCOSE_INGEST_SECRET"]
      end
    end
  end
end
