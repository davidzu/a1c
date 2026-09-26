require "test_helper"

module Api
  module V1
    class SettingsControllerTest < ActionDispatch::IntegrationTest
      setup do
        Setting.delete_all
      end

      test "show creates the settings row if missing" do
        assert_not Setting.any?
        get api_v1_settings_url, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("settings")
        assert_equal "Fast", body["fast_name"]
        assert_equal "Slow", body["slow_name"]
        assert_nil body["weight_kg"]
        assert_nil body["last_a1c"]
        assert_equal 1, Setting.count
      end

      test "updates insulin names" do
        patch api_v1_settings_url, params: { fast_name: "Lispro", slow_name: "Glargine" }, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("settings")
        assert_equal "Lispro", body["fast_name"]
        assert_equal "Glargine", body["slow_name"]
      end

      test "updates weight and a1c with decimals" do
        patch api_v1_settings_url, params: { weight_kg: "78.5", last_a1c: "7.2" }, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("settings")
        assert_in_delta 78.5, body["weight_kg"]
        assert_in_delta 7.2, body["last_a1c"]
      end

      test "partial update keeps other fields" do
        Setting.create!(fast_name: "Lispro", slow_name: "Glargine", weight_kg: 78.5)

        patch api_v1_settings_url, params: { last_a1c: "7.0" }, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("settings")
        assert_equal "Lispro", body["fast_name"]
        assert_in_delta 78.5, body["weight_kg"]
        assert_in_delta 7.0, body["last_a1c"]
      end

      test "rejects blank insulin name" do
        patch api_v1_settings_url, params: { fast_name: "" }, as: :json
        assert_response :unprocessable_content

        body = JSON.parse(response.body)
        assert_equal "validation_failed", body.dig("error", "code")
        assert_equal "fast_name", body.dig("error", "field")
      end

      test "rejects negative a1c" do
        patch api_v1_settings_url, params: { last_a1c: "-1" }, as: :json
        assert_response :unprocessable_content
      end

      test "timezone defaults to Monterrey" do
        get api_v1_settings_url, as: :json
        body = JSON.parse(response.body).fetch("settings")
        assert_equal "America/Monterrey", body["timezone"]
      end

      test "updates timezone with a valid IANA zone" do
        patch api_v1_settings_url, params: { timezone: "America/New_York" }, as: :json
        assert_response :ok

        body = JSON.parse(response.body).fetch("settings")
        assert_equal "America/New_York", body["timezone"]
      end

      test "rejects unknown timezone" do
        patch api_v1_settings_url, params: { timezone: "Mars/Olympus" }, as: :json
        assert_response :unprocessable_content

        body = JSON.parse(response.body)
        assert_equal "validation_failed", body.dig("error", "code")
        assert_equal "timezone", body.dig("error", "field")
      end
    end
  end
end
