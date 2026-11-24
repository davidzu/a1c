# GET /doctor-dashboard (and the older /report) — the doctor report
# (slice 7, per docs/ADR-003-activity-nutrition.md).
#
# The one HTML page in an otherwise API-only app (ADR-001 amended by ADR-003).
# Server-rendered ERB + inline CSS + server-side SVG; printable, no JS.
#
# Access is a time-boxed switch, not a permanent public URL: the page 404s
# unless a window is armed (Setting#report_armed?). Arming is done out of band
# (Api::V1::ReportAccessController or the `a1see-report` script) so the page
# can never turn itself on.
#
# The token is optional and only checked when supplied: the clean URL
# /doctor-dashboard needs nothing but an armed window, while a link that
# already carries ?token= must carry the right one. The switch is the gate —
# the path is guessable, so the armed window is what keeps the page dark.
class ReportController < ActionController::Base
  MAX_DAYS = 90
  DEFAULT_DAYS = 14

  layout "report"

  # The report holds a year of health data behind a URL. Keep it out of search
  # engines, and answer 404 — never 401 — when the switch is off, so the page's
  # existence is not confirmed.
  before_action :set_noindex_header
  before_action :require_report_access

  def show
    days = params[:days].present? ? [ [ params[:days].to_i, 1 ].max, MAX_DAYS ].min : DEFAULT_DAYS
    @report = Report.new(days)

    if params[:day].present?
      @day = @report.day_detail(params[:day])
      render(plain: "Day outside the report window", status: :not_found) if @day.nil?
    end
  end

  private

  def set_noindex_header
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end

  # Fails closed on the switch: no armed window → 404, whichever path and
  # whichever token. A token, when one is configured and supplied, must match;
  # a stale token 404s loudly instead of quietly working.
  def require_report_access
    setting = Setting.instance
    return head :not_found unless setting.report_armed?

    expected = setting.effective_report_token
    provided = params[:token].to_s

    if expected.present? && provided.present?
      unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        return head :not_found
      end
    end

    # Reached with an armed window: the view shows when the link lapses.
    @access_until = setting.report_access_until
  end
end
