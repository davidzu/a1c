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
          a1c_total: a1c_total,
          timezone: settings.timezone
        }
      end

      # A1C:Total — the moving everyday A1C (docs/design-system.md era):
      # the average of the last lab-reported A1C and the glucose-derived GMI
      # over the last 90 days (GMI = 3.31 + 0.02392 × mean glucose mg/dL).
      # Moves daily with the CGM mean; anchors to the lab value. Falls back
      # to whichever source exists.
      #
      # Always a Float: BigDecimal serializes as a JSON *string*, which the
      # Android client's Double field cannot decode.
      def a1c_total
        lab = A1cEntry.order(:measured_on).last&.value || Setting.instance.last_a1c
        gmi = gmi_90d
        return nil if lab.nil? && gmi.nil?
        return (gmi || lab).to_f.round(1) if lab.nil? || gmi.nil?

        ((lab + gmi) / 2).to_f.round(1)
      end

      def gmi_90d
        mean = GlucoseReading.where(time: 90.days.ago..).average(:sgv)
        return nil if mean.nil?

        (3.31 + 0.02392 * mean.to_f).round(1)
      end
    end
  end
end
