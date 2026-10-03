# GET /report — the doctor report (slice 7, per docs/ADR-003-activity-nutrition.md).
#
# The one HTML page in an otherwise API-only app (ADR-001 amended by ADR-003).
# Server-rendered ERB + inline CSS + server-side SVG; printable, no JS.
# No auth: private URL, single user — same contract as the whole API.
class ReportController < ActionController::Base
  MAX_DAYS = 90
  DEFAULT_DAYS = 14

  layout "report"

  def show
    days = params[:days].present? ? [ [ params[:days].to_i, 1 ].max, MAX_DAYS ].min : DEFAULT_DAYS
    @report = Report.new(days)

    if params[:day].present?
      @day = @report.day_detail(params[:day])
      render(plain: "Day outside the report window", status: :not_found) if @day.nil?
    end
  end
end
