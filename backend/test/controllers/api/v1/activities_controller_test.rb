require "test_helper"

module Api
  module V1
    class ActivitiesControllerTest < ActionDispatch::IntegrationTest
      setup do
        ActivitySession.delete_all
      end

      test "ingests a single activity with computed minutes" do
        assert_difference "ActivitySession.count", 1 do
          post api_v1_activities_url, params: {
            started_at: "2026-09-29T07:00:00-06:00",
            ended_at: "2026-09-29T08:05:00-06:00",
            calories_kcal: 320, avg_hr: 128, max_hr: 152,
            source: "Zepp", client_id: "hc:abc123"
          }, as: :json
        end
        assert_response :created
        assert_equal 1, JSON.parse(response.body).dig("ingested")

        session = ActivitySession.last
        assert_equal 65, session.minutes
        assert_equal 320, session.calories_kcal
        assert_equal "hc:abc123", session.client_id
      end

      test "ingests an array and accepts explicit minutes" do
        post api_v1_activities_url, params: [
          { started_at: "2026-09-29T07:00:00-06:00", ended_at: "2026-09-29T08:00:00-06:00",
            minutes: 55, client_id: "hc:a" },
          { started_at: "2026-09-29T18:00:00-06:00", ended_at: "2026-09-29T18:45:00-06:00",
            client_id: "hc:b" },
        ], as: :json

        assert_response :created
        body = JSON.parse(response.body)
        assert_equal 2, body.dig("ingested")
        assert_equal 2, body.dig("received")
        # hc:b has no explicit minutes → computed from the 45-min span.
        assert_equal 45, ActivitySession.find_by(client_id: "hc:b").minutes
      end

      test "is idempotent on client_id (first wins)" do
        payload = { started_at: "2026-09-29T07:00:00-06:00", ended_at: "2026-09-29T08:00:00-06:00",
                    client_id: "hc:same" }

        post api_v1_activities_url, params: payload, as: :json
        assert_response :created

        # Retry with the same client_id: still 201, ingested 0, no dup row,
        # original values untouched.
        post api_v1_activities_url, params: payload.merge(calories_kcal: 999), as: :json
        assert_response :created

        assert_equal 1, ActivitySession.count
        assert_nil ActivitySession.last.calories_kcal
      end

      test "rejects sessions ending before they start" do
        post api_v1_activities_url, params: {
          started_at: "2026-09-29T08:00:00-06:00", ended_at: "2026-09-29T07:00:00-06:00",
          client_id: "hc:bad"
        }, as: :json

        assert_response :unprocessable_content
        assert_equal 0, ActivitySession.count
        assert_equal "validation_failed", JSON.parse(response.body).dig("error", "code")
      end

      test "rejects records without client_id" do
        post api_v1_activities_url, params: {
          started_at: "2026-09-29T07:00:00-06:00", ended_at: "2026-09-29T08:00:00-06:00"
        }, as: :json

        assert_response :unprocessable_content
        assert_equal 0, ActivitySession.count
      end

      test "index returns ascending sessions and clamps hours" do
        ActivitySession.create!(started_at: 400.hours.ago, ended_at: 399.hours.ago,
                                minutes: 60, client_id: "hc:old")
        ActivitySession.create!(started_at: 3.hours.ago, ended_at: 2.hours.ago,
                                minutes: 30, client_id: "hc:new")

        # Default window is 24 h: the 400-hour-old session is outside it.
        get api_v1_activities_url, as: :json
        activities = JSON.parse(response.body).dig("activities")
        assert_equal 1, activities.size
        assert_equal "hc:new", activities.first["client_id"]

        # Clamped to max 336 h — the 400-hour-old session stays out.
        get api_v1_activities_url(params: { hours: 1000 }), as: :json
        assert_equal 1, JSON.parse(response.body).dig("activities").size
      end
    end
  end
end
