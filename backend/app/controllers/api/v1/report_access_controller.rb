module Api
  module V1
    # The switch behind the doctor report. Guarded by its own secret, never by
    # the report token: a link that can arm itself is not a kill switch.
    #
    #   GET   /api/v1/report_access           → state + live URL while armed
    #   PATCH /api/v1/report_access           → { minutes: 180 } / { enabled: false }
    #   POST  /api/v1/report_access/rotate    → new token, old links die
    #
    # If REPORT_ADMIN_SECRET is unset every action is a 404, so an unconfigured
    # deploy cannot be armed remotely at all (falls back to `rails runner`).
    class ReportAccessController < ApplicationController
      DEFAULT_MINUTES = 180

      before_action :require_admin_secret

      def show
        render json: status_payload
      end

      def update
        setting = Setting.instance
        minutes = params[:minutes]

        if disarm_requested?(minutes)
          setting.disarm_report!
        else
          setting.arm_report!(minutes.presence || default_minutes)
        end

        render json: status_payload
      end

      def rotate
        setting = Setting.instance
        setting.rotate_report_token!
        render json: status_payload
      end

      private

      # Explicit off: `enabled: false`, or a non-positive window. Everything
      # else (including a bare PATCH) arms for the default window.
      def disarm_requested?(minutes)
        enabled = params[:enabled]
        return true if enabled == false || enabled.to_s.match?(/\A(false|0|off)\z/i)

        minutes.present? && minutes.to_i <= 0
      end

      def default_minutes
        (ENV["REPORT_ACCESS_DEFAULT_MINUTES"].presence || DEFAULT_MINUTES).to_i
      end

      def require_admin_secret
        expected = ENV["REPORT_ADMIN_SECRET"].presence
        provided = request.headers["X-Report-Admin-Secret"].to_s

        return head :not_found if expected.blank?

        authorized = provided.present? &&
          ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        head :not_found unless authorized
      end

      def status_payload
        setting = Setting.instance
        {
          armed: setting.report_armed?,
          until: setting.report_access_until&.iso8601,
          minutes_left: setting.report_minutes_left,
          url: setting.report_armed? ? report_url_with_token(setting) : nil
        }
      end

      def report_url_with_token(setting)
        token = setting.effective_report_token
        return nil if token.blank?

        "#{request.base_url}/report?token=#{token}"
      end
    end
  end
end
