require "test_helper"

# The interim gate on the v1 API: no per-user auth yet (slice 8), so every
# data route is limited to allowed countries via Cloudflare's CF-IPCountry.
class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    Setting.delete_all
    ENV["API_ALLOWED_COUNTRIES"] = "MX"
  end

  teardown { ENV.delete("API_ALLOWED_COUNTRIES") }

  test "allows a request labelled with an allowed country" do
    get api_v1_settings_url, headers: { "CF-IPCountry" => "MX" }

    assert_response :success
    assert_equal "Fast", response.parsed_body.dig("settings", "fast_name")
  end

  test "blocks other countries with the documented 404 envelope" do
    get api_v1_settings_url, headers: { "CF-IPCountry" => "US" }

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
    assert_equal "application/json", response.media_type
  end

  test "blocks a request with no country label" do
    get api_v1_settings_url

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "covers every data route, reads and writes alike" do
    before = { "CF-IPCountry" => "MX" }
    after_headers = { "CF-IPCountry" => "RU" }

    get api_v1_doses_url, headers: before
    assert_response :success
    get api_v1_doses_url, headers: after_headers
    assert_response :not_found

    get api_v1_glucose_url, headers: before
    assert_response :success
    get api_v1_glucose_url, headers: after_headers
    assert_response :not_found

    get api_v1_days_url, headers: before
    assert_response :success
    get api_v1_days_url, headers: after_headers
    assert_response :not_found

    post api_v1_entries_url,
         params: { type: "sgv", sgv: 120, date: Time.current.to_i * 1000 },
         headers: before, as: :json
    assert_response :created
    post api_v1_entries_url,
         params: { type: "sgv", sgv: 121, date: 1.minute.from_now.to_i * 1000 },
         headers: after_headers, as: :json
    assert_response :not_found
    assert_equal 1, GlucoseReading.count
  end

  test "the filter is off when no countries are configured" do
    ENV.delete("API_ALLOWED_COUNTRIES")

    get api_v1_settings_url, headers: { "CF-IPCountry" => "US" }
    assert_response :success
  end

  test "the admin switch is not geo-gated, so it stays reachable when away" do
    ENV["REPORT_ADMIN_SECRET"] = "admin-secret"

    get api_v1_report_access_url,
        headers: { "CF-IPCountry" => "US", "X-Report-Admin-Secret" => "admin-secret" }

    assert_response :success
  ensure
    ENV.delete("REPORT_ADMIN_SECRET")
  end
end
