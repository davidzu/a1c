require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "unknown API path returns the documented error envelope" do
    get "/api/v1/nope", as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "not_found", body.dig("error", "code")
    assert_equal "Not found", body.dig("error", "message")
    assert body.dig("error").key?("field")
  end

  test "unknown top-level path and root also return the envelope" do
    get "/does-not-exist"

    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body).dig("error", "code")

    get "/"

    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body).dig("error", "code")
  end

  test "known routes are not shadowed by the catch-all" do
    get "/up"
    assert_response :success

    get api_v1_settings_url, as: :json
    assert_response :success
  end
end
