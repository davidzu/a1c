# GET /report — the doctor report (slice 7, per docs/ADR-003-activity-nutrition.md).
#
# The one HTML page in an otherwise API-only app (ADR-001 amended by ADR-003).
# Server-rendered ERB + inline CSS + server-side SVG; printable, no JS.
# No auth: private URL, single user — same contract as the whole API.
class ReportController < ActionController::Base
  MAX_DAYS = 90
  DEFAULT_DAYS = 14

  layout "report"

  # The report holds a year of health data behind a URL. Keep it out of search
  # engines, and optionally require a shared token (REPORT_TOKEN).
  before_action :set_noindex_header
  before_action :require_report_token

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

  # Token is optional: with REPORT_TOKEN unset the report stays reachable by
  # URL (the old contract) but is still marked noindex. When set, a missing or
  # wrong token is a 404 — not a 401 — so the page's existence is not confirmed.
  def require_report_token
    expected = ENV["REPORT_TOKEN"].presence
    return if expected.nil?

    provided = params[:token].to_s
    return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

    head :not_found
  end
end
