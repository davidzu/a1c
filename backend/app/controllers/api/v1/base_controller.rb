# Base for every /api/v1 data endpoint (doses, settings, glucose, entries,
# activities, nutrition, days).
#
# Until slice 8 (ADR-004 identity) lands there is no per-user auth, so the API
# is readable by anyone who finds the host. This gate is the interim: the same
# country allowlist the dashboard uses, applied to the whole v1 surface.
#
#   API_ALLOWED_COUNTRIES=MX   # unset/empty disables the filter (local dev)
#
# Cloudflare labels every request at Render's edge with CF-IPCountry, so the
# header cannot be forged by the client. Blocked requests get the documented
# 404 envelope — not 403 — so a scanner cannot tell the route exists.
#
# Ingest (xDrip, Juggluco, Health Connect) goes out through the phone, so it is
# allowed while the phone is on a Mexican network. If it ever is not, uploads
# fail and each source keeps its own copy (Juggluco's polls.dat, xDrip's
# history, the app's outbox) — nothing is lost, it just waits.
module Api
  module V1
    class BaseController < ApplicationController
      before_action :require_allowed_country

      private

      def require_allowed_country
        allowed = ENV["API_ALLOWED_COUNTRIES"].to_s
          .split(",").map { |code| code.strip.upcase }.reject(&:empty?)
        return if allowed.empty?

        country = request.headers["CF-IPCountry"].to_s.upcase
        return if country.present? && allowed.include?(country)

        Rails.logger.warn(
          "api: blocked country=#{country.presence || 'unknown'} " \
          "ip=#{request.remote_ip} method=#{request.request_method} path=#{request.path}"
        )
        render_error(code: "not_found", message: "Not found", status: :not_found)
      end
    end
  end
end
