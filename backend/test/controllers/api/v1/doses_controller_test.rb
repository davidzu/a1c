require "test_helper"

module Api
  module V1
    class DosesControllerTest < ActionDispatch::IntegrationTest
      setup do
        Dose.delete_all
      end

      test "creates a fast dose" do
        assert_difference "Dose.count", 1 do
          post api_v1_doses_url, params: { units: 6, kind: "fast" }, as: :json
        end
        assert_response :created

        body = JSON.parse(response.body)
        assert_equal "fast", body.dig("dose", "kind")
        assert_equal 6, body.dig("dose", "units")
        assert_not_nil body.dig("dose", "created_at")
      end

      test "creates a slow dose" do
        post api_v1_doses_url, params: { units: 20, kind: "slow" }, as: :json
        assert_response :created
        assert_equal "slow", JSON.parse(response.body).dig("dose", "kind")
      end

      test "rejects zero units" do
        post api_v1_doses_url, params: { units: 0, kind: "fast" }, as: :json
        assert_response :unprocessable_content

        body = JSON.parse(response.body)
        assert_equal "validation_failed", body.dig("error", "code")
        assert_equal "units", body.dig("error", "field")
        assert_equal 0, Dose.count
      end

      test "rejects negative and non-integer units" do
        post api_v1_doses_url, params: { units: -3, kind: "fast" }, as: :json
        assert_response :unprocessable_content

        post api_v1_doses_url, params: { units: 2.5, kind: "fast" }, as: :json
        assert_response :unprocessable_content
      end

      test "rejects unknown kind" do
        post api_v1_doses_url, params: { units: 5, kind: "ultra" }, as: :json
        assert_response :unprocessable_content
        assert_equal 0, Dose.count
      end

      test "index returns recent doses and daily totals" do
        zone = Setting.instance.timezone
        yesterday = (Time.current.in_time_zone(zone).to_date - 1).in_time_zone(zone)
        today = Time.current.in_time_zone(zone).to_date.in_time_zone(zone)

        Dose.create!(units: 5, kind: :fast, taken_at: yesterday.change(hour: 9))
        Dose.create!(units: 10, kind: :slow, taken_at: yesterday.change(hour: 10))
        Dose.create!(units: 7, kind: :fast, taken_at: today.change(hour: 21))

        get api_v1_doses_url, as: :json
        assert_response :ok

        body = JSON.parse(response.body)
        totals = body["daily_totals"]
        assert_equal 2, totals.size
        assert_equal({ "date" => yesterday.to_date.to_s, "fast_units" => 5, "slow_units" => 10, "total_units" => 15 }, totals.first)
        assert_equal({ "date" => today.to_date.to_s, "fast_units" => 7, "slow_units" => 0, "total_units" => 7 }, totals.last)

        doses = body["doses"]
        assert_equal 3, doses.size
        assert_equal 7, doses.last["units"]
      end

      test "recent doses are ordered by effective time, not receive time" do
        # Injected 5 h ago but synced 1 min ago (offline), vs injected 10 min
        # ago but received an hour ago. The list must follow the injection.
        offline = Dose.create!(units: 4, kind: :fast, taken_at: 5.hours.ago,
                               created_at: 1.minute.ago, client_id: "later-sync")
        recent = Dose.create!(units: 6, kind: :fast, taken_at: 10.minutes.ago,
                             created_at: 1.hour.ago, client_id: "earlier-sync")

        get api_v1_doses_url, as: :json
        ids = JSON.parse(response.body)["doses"].map { |d| d["id"] }

        assert_equal [ offline.id, recent.id ], ids
      end

      test "daily totals bucket by local day, not UTC (UTC-6 regression)" do
        # 21:00 Monterrey = 03:00 UTC next day. Must count as the SAME local
        # day as a dose logged at noon Monterrey.
        zone = Setting.instance.timezone
        today = Time.current.in_time_zone(zone).to_date.in_time_zone(zone)

        Dose.create!(units: 4, kind: :fast, taken_at: today.change(hour: 12))
        Dose.create!(units: 3, kind: :slow, taken_at: today.change(hour: 21))

        get api_v1_doses_url, as: :json
        assert_response :ok

        totals = JSON.parse(response.body)["daily_totals"]
        assert_equal 1, totals.size, "evening Monterrey dose must not spill into the next UTC day"
        assert_equal({ "date" => today.to_date.to_s, "fast_units" => 4, "slow_units" => 3, "total_units" => 7 }, totals.first)
      end

      test "accepts taken_at and client_id, echoes them back" do
        post api_v1_doses_url,
             params: { units: 6, kind: "fast", taken_at: "2026-09-20T19:30:00-06:00", client_id: "abc-123" },
             as: :json
        assert_response :created

        body = JSON.parse(response.body).fetch("dose")
        assert_equal "abc-123", body["client_id"]
        # Same instant as "2026-09-20T19:30:00-06:00", serialized in UTC.
        assert_equal "2026-09-21T01:30:00Z", body["taken_at"]
        assert_equal 1, Dose.count
      end

      test "same client_id twice returns the existing dose without duplicating" do
        post api_v1_doses_url, params: { units: 6, kind: "fast", client_id: "abc-123" }, as: :json
        assert_response :created

        post api_v1_doses_url, params: { units: 9, kind: "slow", client_id: "abc-123" }, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("dose")
        assert_equal 6, body["units"], "must return the original dose, not the retry payload"
        assert_equal "fast", body["kind"]
        assert_equal 1, Dose.count
      end

      test "daily totals use taken_at when present" do
        # Logged today (server time) but injected yesterday evening, local.
        zone = Setting.instance.timezone
        yesterday = (Time.current.in_time_zone(zone).to_date - 1).in_time_zone(zone)
        Dose.create!(units: 5, kind: :fast, taken_at: yesterday.change(hour: 20))

        get api_v1_doses_url, as: :json
        totals = JSON.parse(response.body)["daily_totals"]
        assert_equal({ "date" => yesterday.to_date.to_s, "fast_units" => 5, "slow_units" => 0, "total_units" => 5 }, totals.first)
      end

      test "daily totals default to the configured 10-day window" do
        # 30 days of history, but the graph only needs the recent window.
        30.downto(0) { |i| Dose.create!(units: 1, kind: :fast, taken_at: i.days.ago) }

        get api_v1_doses_url, as: :json
        totals = JSON.parse(response.body)["daily_totals"]

        assert_equal 10, totals.size
        assert_equal Time.current.in_time_zone(Setting.instance.timezone).to_date.to_s, totals.last["date"]
      end

      test "daily totals accept a days override and clamp it" do
        30.downto(0) { |i| Dose.create!(units: 1, kind: :fast, taken_at: i.days.ago) }

        get api_v1_doses_url(params: { days: 5 }), as: :json
        assert_equal 5, JSON.parse(response.body)["daily_totals"].size

        get api_v1_doses_url(params: { days: 0 }), as: :json
        assert_equal 1, JSON.parse(response.body)["daily_totals"].size

        # 31 calendar days exist; the 366-day cap cannot invent rows.
        get api_v1_doses_url(params: { days: 9999 }), as: :json
        assert_equal 31, JSON.parse(response.body)["daily_totals"].size
      end

      test "daily totals window is a deploy config parameter" do
        ENV["DOSES_HISTORY_DAYS"] = "3"
        30.downto(0) { |i| Dose.create!(units: 1, kind: :fast, taken_at: i.days.ago) }

        get api_v1_doses_url, as: :json
        assert_equal 3, JSON.parse(response.body)["daily_totals"].size

        # Explicit query wins over the deploy default.
        get api_v1_doses_url(params: { days: 7 }), as: :json
        assert_equal 7, JSON.parse(response.body)["daily_totals"].size
      ensure
        ENV.delete("DOSES_HISTORY_DAYS")
      end

      test "taken_at must be a valid timestamp" do
        post api_v1_doses_url, params: { units: 6, kind: "fast", taken_at: "not-a-date" }, as: :json
        assert_response :unprocessable_content
        assert_equal 0, Dose.count
      end
    end
  end
end
