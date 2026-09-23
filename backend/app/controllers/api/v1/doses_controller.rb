module Api
  module V1
    class DosesController < ApplicationController
      def index
        render json: {
          doses: Dose.recent.reverse.map { |dose| dose_payload(dose) },
          daily_totals: Dose.daily_totals
        }
      end

      def create
        dose = Dose.new(dose_params)
        if dose.save
          render json: { dose: dose_payload(dose) }, status: :created
        else
          render_validation(dose)
        end
      end

      private

      def dose_params
        params.permit(:units, :kind)
      end

      def dose_payload(dose)
        {
          id: dose.id,
          kind: dose.kind,
          units: dose.units,
          created_at: dose.created_at&.iso8601
        }
      end
    end
  end
end
