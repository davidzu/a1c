require "test_helper"

module Api
  module V1
    class DaysControllerTest < ActionDispatch::IntegrationTest
      setup do
        Dose.delete_all
        NutritionEntry.delete_all
        ActivitySession.delete_all
      end

      test "unifies insulin, carbs, and exercise per local day" do
        # All three events land on the same local day, inside the default window.
        zone = Setting.instance.timezone
        day = Time.current.in_time_zone(zone).to_date.in_time_zone(zone)

        Dose.create!(units: 6, kind: "fast", taken_at: day.change(hour: 8))
        Dose.create!(units: 4, kind: "fast", taken_at: day.change(hour: 13))
        Dose.create!(units: 18, kind: "slow", taken_at: day.change(hour: 22, min: 30))
        NutritionEntry.create!(taken_at: day.change(hour: 13, min: 30), carbs_g: 45,
                               calories_kcal: 620, client_id: "hc:lunch")
        ActivitySession.create!(started_at: day.change(hour: 7),
                                ended_at: day.change(hour: 8), minutes: 60,
                                client_id: "hc:run")

        get api_v1_days_url, as: :json
        assert_response :success

        days = JSON.parse(response.body).dig("days")
        assert_equal 1, days.size

        day_row = days.first
        assert_equal day.to_date.to_s, day_row["date"]
        assert_equal 10, day_row["fast_units"]
        assert_equal 18, day_row["slow_units"]
        assert_equal 28, day_row["total_units"]
        assert_equal 45, day_row["carbs_g"]
        assert_equal 620, day_row["calories_kcal"]
        assert_equal 60, day_row["exercise_min"]
      end

      test "buckets a late-night UTC dose into the previous local day" do
        # 21:00 Monterrey = 03:00 next-day UTC; it must stay on the local date.
        zone = Setting.instance.timezone
        day = Time.current.in_time_zone(zone).to_date.in_time_zone(zone)
        Dose.create!(units: 6, kind: "fast", taken_at: day.change(hour: 21))

        get api_v1_days_url, as: :json
        days = JSON.parse(response.body).dig("days")
        assert_equal [ day.to_date.to_s ], days.map { |d| d["date"] }
      end

      test "days without events are absent, not zero rows" do
        Dose.create!(units: 5, kind: "fast", taken_at: 2.days.ago)

        get api_v1_days_url, as: :json
        days = JSON.parse(response.body).dig("days")
        assert_equal 1, days.size
      end

      test "days window ends today, not at the newest inserted day key" do
        zone = Setting.instance.timezone
        today = Time.current.in_time_zone(zone).to_date

        # A workout-only day well outside the window. Exercises are merged
        # into the day hash last, so a "last N keys" implementation returns
        # this row and drops today (regression: /days ignored the calendar).
        old_day = (today - 90).in_time_zone(zone).change(hour: 9)
        ActivitySession.create!(started_at: old_day, ended_at: old_day + 1.hour,
                                minutes: 60, client_id: "hc:old-run")
        Dose.create!(units: 5, kind: "fast", taken_at: today.in_time_zone(zone).change(hour: 12))

        get api_v1_days_url(params: { days: 1 }), as: :json
        days = JSON.parse(response.body).dig("days")

        assert_equal [ today.to_s ], days.map { |d| d["date"] }
        assert_equal 5, days.first["fast_units"]
      end

      test "days window excludes events older than N calendar days" do
        zone = Setting.instance.timezone
        today = Time.current.in_time_zone(zone).to_date

        Dose.create!(units: 4, kind: "fast", taken_at: today.in_time_zone(zone).change(hour: 12))
        Dose.create!(units: 9, kind: "fast", taken_at: (today - 10).in_time_zone(zone).change(hour: 12))

        get api_v1_days_url(params: { days: 3 }), as: :json
        days = JSON.parse(response.body).dig("days")

        assert_equal [ today.to_s ], days.map { |d| d["date"] }
      end

      test "days param clamps and defaults to 30" do
        40.downto(0) do |i|
          Dose.create!(units: 1, kind: "fast", taken_at: i.days.ago)
        end

        get api_v1_days_url, as: :json
        assert_equal 30, JSON.parse(response.body).dig("days").size

        # Max clamp is 180; only 41 calendar days of data exist → all 41.
        get api_v1_days_url(params: { days: 1000 }), as: :json
        assert_equal 41, JSON.parse(response.body).dig("days").size
      end

      test "returns empty array when nothing logged" do
        get api_v1_days_url, as: :json
        assert_response :success
        assert_equal [], JSON.parse(response.body).dig("days")
      end
    end
  end
end
