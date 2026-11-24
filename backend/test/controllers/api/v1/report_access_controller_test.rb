require "test_helper"

# The kill switch for GET /report. Guarded by REPORT_ADMIN_SECRET only.
class Api::V1::ReportAccessControllerTest < ActionDispatch::IntegrationTest
  SECRET = "admin-secret"

  setup do
    Setting.delete_all
    ENV["REPORT_ADMIN_SECRET"] = SECRET
    ENV["REPORT_TOKEN"] = "report-token"
  end

  teardown do
    ENV.delete("REPORT_ADMIN_SECRET")
    ENV.delete("REPORT_TOKEN")
    ENV.delete("REPORT_ACCESS_DEFAULT_MINUTES")
  end

  test "404s when no admin secret is configured" do
    ENV.delete("REPORT_ADMIN_SECRET")

    patch api_v1_report_access_url, params: { minutes: 60 }, headers: auth
    assert_response :not_found
    assert_nil Setting.instance.report_access_until
  end

  test "404s on a wrong or missing secret" do
    patch api_v1_report_access_url, params: { minutes: 60 }
    assert_response :not_found

    patch api_v1_report_access_url, params: { minutes: 60 },
          headers: { "X-Report-Admin-Secret" => "nope" }
    assert_response :not_found

    assert_nil Setting.instance.report_access_until
  end

  test "reports the disarmed state" do
    get api_v1_report_access_url, headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal false, body["armed"]
    assert_nil body["until"]
    assert_nil body["url"]
  end

  test "arms a window and returns the live url" do
    patch api_v1_report_access_url, params: { minutes: 90 }, headers: auth
    assert_response :success

    body = response.parsed_body
    assert_equal true, body["armed"]
    assert_includes body["url"], "/report?token=report-token"
    assert_in_delta 90, body["minutes_left"], 2
    assert_in_delta 90.minutes.from_now.to_i, Time.zone.parse(body["until"]).to_i, 5
  end

  test "a bare patch arms the default window" do
    patch api_v1_report_access_url, headers: auth
    assert_response :success
    assert_in_delta 180, response.parsed_body["minutes_left"], 2
  end

  test "the default window is configurable" do
    ENV["REPORT_ACCESS_DEFAULT_MINUTES"] = "30"

    patch api_v1_report_access_url, headers: auth
    assert_response :success
    assert_in_delta 30, response.parsed_body["minutes_left"], 2
  end

  test "clamps a window to one week" do
    patch api_v1_report_access_url, params: { minutes: 99_999 }, headers: auth
    assert_response :success
    assert_in_delta Setting::REPORT_MAX_MINUTES, response.parsed_body["minutes_left"], 2
  end

  test "disarms with enabled false, a zero window, or off" do
    [ { enabled: false }, { minutes: 0 }, { enabled: "off" } ].each do |params|
      Setting.instance.arm_report!(60)

      patch api_v1_report_access_url, params: params, headers: auth
      assert_response :success
      assert_equal false, response.parsed_body["armed"]
      assert_nil Setting.instance.reload.report_access_until
    end
  end

  test "rotating the token invalidates the old url" do
    Setting.instance.arm_report!(60)
    old_url = get_url_from_status

    post rotate_api_v1_report_access_url, headers: auth
    assert_response :success

    new_url = response.parsed_body["url"]
    refute_equal old_url, new_url

    get new_url
    assert_response :success

    get old_url
    assert_response :not_found
  end

  test "the report token alone cannot arm the page" do
    get report_url(params: { token: "report-token" })
    assert_response :not_found

    get api_v1_report_access_url, headers: { "X-Report-Admin-Secret" => "report-token" }
    assert_response :not_found
  end

  private

  def auth
    { "X-Report-Admin-Secret" => SECRET }
  end

  def get_url_from_status
    get api_v1_report_access_url, headers: auth
    response.parsed_body["url"]
  end
end
