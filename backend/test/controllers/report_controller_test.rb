require "test_helper"

class ReportControllerTest < ActionDispatch::IntegrationTest
  setup do
    Dose.delete_all
    GlucoseReading.delete_all
    NutritionEntry.delete_all
    ActivitySession.delete_all
    A1cEntry.delete_all
    Setting.delete_all
  end

  test "renders the report shell with no data" do
    get report_url
    assert_response :success
    assert_match "Glucose report", response.body
    assert_match "No CGM readings in this window yet.", response.body
  end

  test "computes ADA core metrics from readings" do
    # 5×100, 3×90, 2×200 → mean 117.0, GMI 6.1, CV 35.7, TIR 80%, TAR L1 20%.
    5.times { |i| GlucoseReading.create!(sgv: 100, time: (i + 1).hours.ago) }
    3.times { |i| GlucoseReading.create!(sgv: 90, time: (i + 10).hours.ago) }
    2.times { |i| GlucoseReading.create!(sgv: 200, time: (i + 20).hours.ago) }

    get report_url
    assert_response :success
    assert_match "117.0", response.body
    assert_match "6.1%", response.body
    assert_match "35.7%", response.body
    assert_match "80.0%", response.body
    assert_match "20.0%", response.body
  end

  test "days param clamps between 1 and 90, defaults 14" do
    get report_url(params: { days: 500 })
    assert_response :success
    assert_match "window: 90 days", response.body

    get report_url(params: { days: 0 })
    assert_match "window: 1 days", response.body

    get report_url
    assert_match "window: 14 days", response.body
  end

  test "day detail renders dose, meal, and workout markers" do
    GlucoseReading.create!(sgv: 120, time: 3.hours.ago)
    GlucoseReading.create!(sgv: 140, time: 1.hour.ago)
    Dose.create!(units: 5, kind: "fast", taken_at: 2.hours.ago)
    NutritionEntry.create!(taken_at: 2.hours.ago, carbs_g: 45, calories_kcal: 620, client_id: "hc:lunch")
    ActivitySession.create!(started_at: 4.hours.ago, ended_at: 3.hours.ago, minutes: 60, client_id: "hc:run")

    day = Time.current.in_time_zone("America/Monterrey").to_date.to_s
    get report_url(params: { day: day })
    assert_response :success
    assert_match "Day detail", response.body
    assert_match "polyline", response.body
    assert_match "5 u", response.body
    assert_match "45 g carbs", response.body
    assert_match "<td>Exercise</td>", response.body
    assert_match "<td>60 min</td>", response.body
  end

  test "day outside the window returns 404" do
    get report_url(params: { day: "1990-01-01" })
    assert_response :not_found
  end

  test "A1C history shows lab entry and GMI trend" do
    A1cEntry.create!(measured_on: 2.days.ago.to_date, value: 7.2)
    GlucoseReading.create!(sgv: 150, time: 1.hour.ago)

    get report_url
    assert_response :success
    assert_match "lab A1C", response.body
    assert_match "GMI trend", response.body
  end
end
