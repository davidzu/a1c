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
        travel_to Time.zone.parse("2026-09-22 09:00:00") do
          Dose.create!(units: 5, kind: :fast)
          Dose.create!(units: 10, kind: :slow)
        end
        travel_to Time.zone.parse("2026-09-23 21:00:00") do
          Dose.create!(units: 7, kind: :fast)
        end

        get api_v1_doses_url, as: :json
        assert_response :ok

        body = JSON.parse(response.body)
        totals = body["daily_totals"]
        assert_equal 2, totals.size
        assert_equal({ "date" => "2026-09-22", "fast_units" => 5, "slow_units" => 10, "total_units" => 15 }, totals.first)
        assert_equal({ "date" => "2026-09-23", "fast_units" => 7, "slow_units" => 0, "total_units" => 7 }, totals.last)

        doses = body["doses"]
        assert_equal 3, doses.size
        assert_equal 7, doses.last["units"]
      end

      test "daily totals bucket by local day, not UTC (UTC-6 regression)" do
        # 21:00 Monterrey = 03:00 UTC next day. Must count as the SAME local
        # day as a dose logged at noon Monterrey.
        travel_to Time.zone.parse("2026-09-22 12:00:00 -06:00") do
          Dose.create!(units: 4, kind: :fast)
        end
        travel_to Time.zone.parse("2026-09-22 21:00:00 -06:00") do
          Dose.create!(units: 3, kind: :slow)
        end

        get api_v1_doses_url, as: :json
        assert_response :ok

        totals = JSON.parse(response.body)["daily_totals"]
        assert_equal 1, totals.size, "evening Monterrey dose must not spill into the next UTC day"
        assert_equal({ "date" => "2026-09-22", "fast_units" => 4, "slow_units" => 3, "total_units" => 7 }, totals.first)
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
        Dose.create!(units: 5, kind: :fast, taken_at: Time.zone.parse("2026-09-21 20:00:00 -06:00"))

        get api_v1_doses_url, as: :json
        totals = JSON.parse(response.body)["daily_totals"]
        assert_equal({ "date" => "2026-09-21", "fast_units" => 5, "slow_units" => 0, "total_units" => 5 }, totals.first)
      end

      test "taken_at must be a valid timestamp" do
        post api_v1_doses_url, params: { units: 6, kind: "fast", taken_at: "not-a-date" }, as: :json
        assert_response :unprocessable_content
        assert_equal 0, Dose.count
      end
    end
  end
end
