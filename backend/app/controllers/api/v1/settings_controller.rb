module Api
  module V1
    class SettingsController < ApplicationController
      def show
        render json: { settings: settings_payload(Setting.instance) }
      end

      def update
        settings = Setting.instance
        if settings.update(settings_params)
          render json: { settings: settings_payload(settings.reload) }
        else
          render_validation(settings)
        end
      end

      private

      def settings_params
        params.permit(:fast_name, :slow_name, :weight_kg, :last_a1c, :timezone)
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
