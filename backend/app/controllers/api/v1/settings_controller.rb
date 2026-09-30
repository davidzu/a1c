module Api
  module V1
    class SettingsController < ApplicationController
      def show
        render json: { settings: settings_payload(Setting.instance) }
      end

      def update
        settings = Setting.instance
        if settings.update(settings_params)
          record_a1c_if_present(settings)
          render json: { settings: settings_payload(settings.reload) }
        else
          render_validation(settings)
        end
      end

      private

      def settings_params
        params.permit(:fast_name, :slow_name, :weight_kg, :last_a1c, :timezone)
      end

      # A1C is a series, not just a current value: every PATCH that sets
      # last_a1c appends/upserts today's point (ADR-003). Same-day updates
      # overwrite — the latest fingerstick of the day wins.
      def record_a1c_if_present(settings)
        return unless settings.last_a1c.present?
        return unless settings.saved_change_to_last_a1c?

        A1cEntry.upsert(
          { measured_on: current_local_date, value: settings.last_a1c },
          unique_by: :measured_on
        )
      end

      def current_local_date
        zone = Setting.instance.timezone
        Time.current.in_time_zone(zone).to_date
      end

      def settings_payload(settings)
        {
          fast_name: settings.fast_name,
          slow_name: settings.slow_name,
          weight_kg: settings.weight_kg&.to_f,
          last_a1c: settings.last_a1c&.to_f,
          timezone: settings.timezone
        }
      end
    end
  end
end
