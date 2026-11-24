# GET /report — the doctor report (slice 7, per docs/ADR-003-activity-nutrition.md).
#
# The one HTML page in an otherwise API-only app (ADR-001 amended by ADR-003).
# Server-rendered ERB + inline CSS + server-side SVG; printable, no JS.
#
# Access is a time-boxed switch, not a permanent public URL: the page 404s
# unless a window is armed (Setting#report_armed?) and the request carries the
# current token. Arming is done out of band (Api::V1::ReportAccessController
# or the `a1see-report` script) so the link itself can never turn the page on.
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

  # Fails closed at every step: no armed window → 404; no token configured →
  # 404 (never "open because nobody set a secret").
  def require_report_access
    setting = Setting.instance
    expected = setting.effective_report_token
    provided = params[:token].to_s

    authorized = setting.report_armed? &&
      expected.present? &&
      provided.present? &&
      ActiveSupport::SecurityUtils.secure_compare(provided, expected)

    return head :not_found unless authorized

    # Only reached with a valid token: the view shows when the link lapses.
    @access_until = setting.report_access_until
  end
end
