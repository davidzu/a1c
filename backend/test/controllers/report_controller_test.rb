require "test_helper"

# The report is closed by default and only opens inside an armed window.
# /doctor-dashboard is the permanent address and needs nothing but the switch;
# /report still honours a ?token= link if one is supplied.
class ReportControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "test-report-token"

  setup do
    Dose.delete_all
    GlucoseReading.delete_all
    NutritionEntry.delete_all
    ActivitySession.delete_all
    A1cEntry.delete_all
    Setting.delete_all

    ENV["REPORT_TOKEN"] = TOKEN
    Setting.instance.arm_report!(60)
  end

  teardown do
    ENV.delete("REPORT_TOKEN")
    ENV.delete("REPORT_ALLOWED_COUNTRIES")
  end

  test "renders the report shell with no data" do
    get_report
    assert_response :success
    assert_match "Glucose report", response.body
    assert_match "No CGM readings in this window yet.", response.body
  end

  test "computes ADA core metrics from readings" do
    # 5×100, 3×90, 2×200 → mean 117.0, GMI 6.1, CV 35.7, TIR 80%, TAR L1 20%.
    5.times { |i| GlucoseReading.create!(sgv: 100, time: (i + 1).hours.ago) }
    3.times { |i| GlucoseReading.create!(sgv: 90, time: (i + 10).hours.ago) }
    2.times { |i| GlucoseReading.create!(sgv: 200, time: (i + 20).hours.ago) }

    get_report
    assert_response :success
    assert_match "117.0", response.body
    assert_match "6.1%", response.body
    assert_match "35.7%", response.body
    assert_match "80.0%", response.body
    assert_match "20.0%", response.body
  end

  test "days param clamps between 1 and 90, defaults 14" do
    get_report(days: 500)
    assert_response :success
    assert_match "window: 90 days", response.body

    get_report(days: 0)
    assert_match "window: 1 days", response.body

    get_report
    assert_match "window: 14 days", response.body
  end

  test "day detail renders dose, meal, and workout markers" do
    GlucoseReading.create!(sgv: 120, time: 3.hours.ago)
    GlucoseReading.create!(sgv: 140, time: 1.hour.ago)
    Dose.create!(units: 5, kind: "fast", taken_at: 2.hours.ago)
    NutritionEntry.create!(taken_at: 2.hours.ago, carbs_g: 45, calories_kcal: 620, client_id: "hc:lunch")
    ActivitySession.create!(started_at: 4.hours.ago, ended_at: 3.hours.ago, minutes: 60, client_id: "hc:run")

    day = Time.current.in_time_zone("America/Monterrey").to_date.to_s
    get_report(day: day)
    assert_response :success
    assert_match "Day detail", response.body
    assert_match "polyline", response.body
    assert_match "5 u", response.body
    assert_match "45 g carbs", response.body
    assert_match "<td>Exercise</td>", response.body
    assert_match "<td>60 min</td>", response.body
  end

  test "day outside the window returns 404" do
    get_report(day: "1990-01-01")
    assert_response :not_found
  end

  test "A1C history shows lab entry and GMI trend" do
    A1cEntry.create!(measured_on: 2.days.ago.to_date, value: 7.2)
    GlucoseReading.create!(sgv: 150, time: 1.hour.ago)

    get_report
    assert_response :success
    assert_match "lab A1C", response.body
    assert_match "GMI trend", response.body
  end

  test "TBR and TAR appear as cards in percent with their goals" do
    # 60 (below), 100 + 150 (in range), 300 (above) → TBR 25%, TAR 25%.
    [ 60, 100, 150, 300 ].each_with_index do |sgv, i|
      GlucoseReading.create!(sgv: sgv, time: (i + 1).hours.ago)
    end

    get_report
    assert_response :success

    assert_match "TBR · below 70", response.body
    assert_match "TAR · above 180", response.body
    assert_match %(<div class="value flag-bad">25.0%</div>), response.body
    assert_match "goal &lt; 4%", response.body
    assert_match "goal &lt; 25%", response.body
  end

  test "days of data is a legend under the cards, not a card" do
    GlucoseReading.create!(sgv: 120, time: 1.hour.ago)

    get_report
    assert_response :success

    assert_match "Days of data:", response.body
    refute_match %(<div class="label">Days of data</div>), response.body
  end

  test "the A1C chart is anchored to the last lab draw" do
    A1cEntry.create!(measured_on: 10.days.ago.to_date, value: 7.2)
    GlucoseReading.create!(sgv: 150, time: 1.hour.ago)

    get_report(days: 14)
    assert_response :success

    # Legend under the graph, with value and date.
    assert_match "Last A1C: 7.2%", response.body
    assert_match 10.days.ago.to_date.to_s, response.body

    # The lab value is a line across the graph, labelled.
    assert_match "lab 7.2%", response.body

    # Y axis is explained.
    assert_match "A1C / GMI (%)", response.body
  end

  test "the A1C chart starts at the report window when there is no lab" do
    GlucoseReading.create!(sgv: 150, time: 1.hour.ago)

    get_report(days: 7)
    assert_response :success

    assert_match "A1C history", response.body
    refute_match "Last A1C:", response.body
  end

  test "daily context is the last block on the page" do
    Dose.create!(units: 4, kind: :fast, taken_at: Time.current)

    get_report
    assert_response :success

    # "footnote" also appears in the layout CSS, so compare against its text.
    assert_operator response.body.index("A1C history"), :<, response.body.index("Daily context")
    assert_operator response.body.index("Daily context"), :<, response.body.index("Units: mg/dL")
  end

  test "marks the page noindex in headers and markup" do
    get_report

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_match '<meta name="robots" content="noindex, nofollow">', response.body
  end

  test "shows when the link lapses" do
    get_report
    assert_response :success

    until_time = Setting.instance.report_access_until.in_time_zone("America/Monterrey").strftime("%H:%M")
    assert_match "link live until #{until_time}", response.body
  end

  test "navigation stays on the permanent path without a token" do
    zone = Setting.instance.timezone
    today = Time.current.in_time_zone(zone).to_date
    Dose.create!(units: 4, kind: :fast, taken_at: Time.current)

    get_report
    assert_response :success

    assert_match "day=#{today}", response.body
    refute_match "token=", response.body
    assert_match "href=\"/doctor-dashboard?", response.body
  end

  test "a legacy token link keeps its token and keeps working" do
    get report_url(params: { token: TOKEN })
    assert_response :success

    assert_match "token=#{TOKEN}", response.body
  end

  # ---- the switch ---------------------------------------------------------

  test "the permanent url needs an armed window, no token" do
    Setting.instance.disarm_report!

    get doctor_dashboard_url
    assert_response :not_found

    Setting.instance.arm_report!(60)

    get doctor_dashboard_url
    assert_response :success
  end

  test "a disarmed report is a 404 even with the right token" do
    Setting.instance.disarm_report!

    get report_url(params: { token: TOKEN })
    assert_response :not_found
  end

  test "an expired window is a 404" do
    Setting.instance.update!(report_access_until: 1.minute.ago)

    get doctor_dashboard_url
    assert_response :not_found
  end

  test "a supplied token must match when one is configured" do
    get report_url(params: { token: "wrong" })
    assert_response :not_found

    get report_url(params: { token: TOKEN })
    assert_response :success
  end

  test "an armed report with no token configured still opens" do
    ENV.delete("REPORT_TOKEN")
    Setting.instance.update!(report_token: nil)

    get doctor_dashboard_url
    assert_response :success
  end

  test "a rotated database token invalidates the old token, not the clean url" do
    Setting.instance.update!(report_token: "rotated-token")

    get report_url(params: { token: TOKEN })
    assert_response :not_found

    get report_url(params: { token: "rotated-token" })
    assert_response :success

    get doctor_dashboard_url
    assert_response :success
  end

  # ---- country filter (Cloudflare's CF-IPCountry at Render's edge) --------

  test "allows the listed country" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"

    get doctor_dashboard_url, headers: { "CF-IPCountry" => "MX" }
    assert_response :success
  end

  test "blocks every other country while armed" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"

    get doctor_dashboard_url, headers: { "CF-IPCountry" => "US" }
    assert_response :not_found

    get doctor_dashboard_url, headers: { "CF-IPCountry" => "RU" }
    assert_response :not_found
  end

  test "blocks a request with no country label at all" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"

    get doctor_dashboard_url
    assert_response :not_found
  end

  test "the filter is off when no countries are configured" do
    get doctor_dashboard_url, headers: { "CF-IPCountry" => "US" }
    assert_response :success
  end

  test "a valid token is the escape hatch for a mislabelled network" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"

    get doctor_dashboard_url, headers: { "CF-IPCountry" => "US" }
    assert_response :not_found

    get report_url(params: { token: TOKEN }), headers: { "CF-IPCountry" => "US" }
    assert_response :success
  end

  test "a wrong token does not bypass the country filter" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"

    get report_url(params: { token: "wrong" }), headers: { "CF-IPCountry" => "US" }
    assert_response :not_found
  end

  test "the switch still wins over an allowed country" do
    ENV["REPORT_ALLOWED_COUNTRIES"] = "MX"
    Setting.instance.disarm_report!

    get doctor_dashboard_url, headers: { "CF-IPCountry" => "MX" }
    assert_response :not_found
  end

  private

  def get_report(extra = {})
    get doctor_dashboard_url(params: extra)
  end
end
