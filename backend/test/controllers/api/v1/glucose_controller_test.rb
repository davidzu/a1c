require "test_helper"

module Api
  module V1
    class GlucoseControllerTest < ActionDispatch::IntegrationTest
      setup do
        GlucoseReading.delete_all
      end

      test "returns readings ascending with mmol conversion" do
        GlucoseReading.create!(sgv: 90, time: 3.hours.ago)
        GlucoseReading.create!(sgv: 108, time: 2.hours.ago)

        get api_v1_glucose_url, as: :json
        assert_response :success

        glucose = JSON.parse(response.body).dig("glucose")
        assert_equal 2, glucose.size
        assert_equal 90, glucose.first["sgv"]
        assert_equal 5.0, glucose.first["mmol_l"]
        assert_equal 6.0, glucose.last["mmol_l"]
      end

      test "hours caps at 336 and defaults to 24" do
        GlucoseReading.create!(sgv: 100, time: 400.hours.ago)
        GlucoseReading.create!(sgv: 100, time: 2.hours.ago)

        get api_v1_glucose_url(params: { hours: 1000 }), as: :json
        assert_equal 1, JSON.parse(response.body).dig("glucose").size

        get api_v1_glucose_url(params: { hours: 3 }), as: :json
        assert_equal 1, JSON.parse(response.body).dig("glucose").size
      end

      test "returns empty array when no readings" do
        get api_v1_glucose_url, as: :json
        assert_response :success
        assert_equal [], JSON.parse(response.body).dig("glucose")
      end
    end
  end
end
