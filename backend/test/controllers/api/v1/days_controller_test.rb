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
        # All three events land on the same local day (UTC-6): 2026-09-28.
        Dose.create!(units: 6, kind: "fast", taken_at: "2026-09-28T08:00:00-06:00")
        Dose.create!(units: 4, kind: "fast", taken_at: "2026-09-28T13:00:00-06:00")
        Dose.create!(units: 18, kind: "slow", taken_at: "2026-09-28T22:30:00-06:00")
        NutritionEntry.create!(taken_at: "2026-09-28T13:30:00-06:00", carbs_g: 45,
                               calories_kcal: 620, client_id: "hc:lunch")
        ActivitySession.create!(started_at: "2026-09-28T07:00:00-06:00",
                                ended_at: "2026-09-28T08:00:00-06:00", minutes: 60,
                                client_id: "hc:run")

        get api_v1_days_url, as: :json
        assert_response :success

        days = JSON.parse(response.body).dig("days")
        assert_equal 1, days.size

        day = days.first
        assert_equal "2026-09-28", day["date"]
        assert_equal 10, day["fast_units"]
        assert_equal 18, day["slow_units"]
        assert_equal 28, day["total_units"]
        assert_equal 45, day["carbs_g"]
        assert_equal 620, day["calories_kcal"]
        assert_equal 60, day["exercise_min"]
      end

      test "buckets a late-night UTC dose into the previous local day" do
        # 21:00 Monterrey = 03:00 next-day UTC; must stay on 2026-09-28.
        Dose.create!(units: 6, kind: "fast", taken_at: "2026-09-28T21:00:00-06:00")

        get api_v1_days_url, as: :json
        days = JSON.parse(response.body).dig("days")
        assert_equal ["2026-09-28"], days.map { |d| d["date"] }
      end

      test "days without events are absent, not zero rows" do
        Dose.create!(units: 5, kind: "fast", taken_at: 2.days.ago)

        get api_v1_days_url, as: :json
        days = JSON.parse(response.body).dig("days")
        assert_equal 1, days.size
      end

      test "days param clamps and defaults to 30" do
        40.downto(1) do |i|
          Dose.create!(units: 1, kind: "fast", taken_at: i.days.ago)
        end

        get api_v1_days_url, as: :json
        assert_equal 30, JSON.parse(response.body).dig("days").size

        # Max clamp is 180; only 40 days of data exist → all 40 returned.
        get api_v1_days_url(params: { days: 1000 }), as: :json
        assert_equal 40, JSON.parse(response.body).dig("days").size
      end

      test "returns empty array when nothing logged" do
        get api_v1_days_url, as: :json
        assert_response :success
        assert_equal [], JSON.parse(response.body).dig("days")
      end
    end
  end
end
