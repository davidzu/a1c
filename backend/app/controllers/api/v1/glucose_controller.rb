module Api
  module V1
    class GlucoseController < ApplicationController
      MAX_HOURS = 336

      def index
        hours = params[:hours].present? ? [[params[:hours].to_i, 1].max, MAX_HOURS].min : 24
        readings = GlucoseReading.last_hours(hours)
        render json: {
          glucose: readings.map { |r| glucose_payload(r) },
        }
      end

      private

      def glucose_payload(reading)
        {
          time: reading.time.iso8601,
          sgv: reading.sgv,
          mmol_l: reading.mmol_l,
          direction: reading.direction,
          device: reading.device,
        }
      end
    end
  end
end
