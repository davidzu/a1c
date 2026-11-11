module Api
  module V1
    class DosesController < ApplicationController
      # Upper bound for the graph window; the default comes from deploy config
      # (DOSES_HISTORY_DAYS) so the payload never grows with account age.
      MAX_DAYS = 366
      DEFAULT_DAYS = 10

      def index
        render json: {
          doses: Dose.recent.reverse.map { |dose| dose_payload(dose) },
          daily_totals: Dose.daily_totals(window_days)
        }
      end

      def create
        dose = Dose.new(dose_params)

        # Rails type-casts unparseable datetimes to nil; reject that explicitly.
        if params[:taken_at].present? && parse_taken_at(params[:taken_at]).nil?
          dose.errors.add(:taken_at, "must be a valid ISO8601 timestamp")
          return render_validation(dose)
        end

        # Idempotency: the Android app retries with the same client_id when a
        # request is ambiguous (timeout, offline queue sync). Same client_id
        # twice = the same dose, returned as-is, never duplicated.
        if dose.client_id.present? && (existing = Dose.find_by(client_id: dose.client_id))
          return render json: { dose: dose_payload(existing) }, status: :ok
        end

        if dose.save
          render json: { dose: dose_payload(dose) }, status: :created
        else
          render_validation(dose)
        end
      end

      private

      # `?days=N` overrides; otherwise the deploy-time default applies. Read at
      # request time (not as a constant) so tests and config changes take hold
      # without a restart.
      def window_days
        raw = params[:days].presence
        days = raw ? raw.to_i : ENV.fetch("DOSES_HISTORY_DAYS", DEFAULT_DAYS).to_i
        [[days, 1].max, MAX_DAYS].min
      end

      def dose_params
        params.permit(:units, :kind, :taken_at, :client_id)
      end

      def parse_taken_at(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def dose_payload(dose)
        {
          id: dose.id,
          kind: dose.kind,
          units: dose.units,
          taken_at: dose.taken_at&.iso8601,
          client_id: dose.client_id,
          created_at: dose.created_at&.iso8601
        }
      end
    end
  end
end
