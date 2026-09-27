require "test_helper"

module Api
  module V1
    class EntriesControllerTest < ActionDispatch::IntegrationTest
      setup do
        GlucoseReading.delete_all
      end

      test "ingests a single sgv entry" do
        assert_difference "GlucoseReading.count", 1 do
          post api_v1_entries_url, params: {
            type: "sgv", sgv: 106, date: 1_760_000_000_000, direction: "Flat", device: "xDrip"
          }, as: :json
        end
        assert_response :created
        assert_equal 1, JSON.parse(response.body).dig("ingested")

        reading = GlucoseReading.order(:time).last
        assert_equal 106, reading.sgv
        assert_equal "Flat", reading.direction
        assert_equal "xDrip", reading.device
        assert_in_delta Time.at(1_760_000_000), reading.time, 1
      end

      test "ingests an array of entries and skips non-glucose types" do
        cal = { type: "cal", slope: 1.0, date: 1_760_000_000_000 }

        assert_difference "GlucoseReading.count", 2 do
          post api_v1_entries_url, params: [
            { type: "sgv", sgv: 100, date: 1_760_000_000_000 },
            cal,
            { type: "sgv", sgv: 105, dateString: "2026-09-27T14:35:00-06:00" },
          ], as: :json
        end
        assert_response :created
        body = JSON.parse(response.body)
        assert_equal 2, body.dig("ingested")
        assert_equal 3, body.dig("received")
      end

      test "is idempotent on time (upsert, no duplicates)" do
        entry = { type: "sgv", sgv: 106, date: 1_760_000_000_000 }

        post api_v1_entries_url, params: entry, as: :json
        post api_v1_entries_url, params: entry.merge(sgv: 108), as: :json

        assert_equal 1, GlucoseReading.count
        assert_equal 106, GlucoseReading.last.sgv
      end

      test "rejects entries without a value or a parsable time" do
        post api_v1_entries_url, params: { type: "sgv", sgv: 0, date: 1_760_000_000_000 }, as: :json
        post api_v1_entries_url, params: { type: "sgv", sgv: 100, dateString: "not-a-date" }, as: :json

        assert_equal 0, GlucoseReading.count
      end

      test "enforces the shared secret when configured" do
        ENV["GLUCOSE_INGEST_SECRET"] = "topsecret"

        post api_v1_entries_url, params: { type: "sgv", sgv: 100, date: 1_760_000_000_000 }, as: :json
        assert_response :unauthorized

        post api_v1_entries_url,
          params: { type: "sgv", sgv: 100, date: 1_760_000_000_000 },
          headers: { "api-secret" => Digest::SHA1.hexdigest("topsecret") },
          as: :json
        assert_response :created
      ensure
        ENV["GLUCOSE_INGEST_SECRET"] = nil
      end
    end
  end
end
