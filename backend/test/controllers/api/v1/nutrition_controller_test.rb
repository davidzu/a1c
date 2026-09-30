require "test_helper"

module Api
  module V1
    class NutritionControllerTest < ActionDispatch::IntegrationTest
      setup do
        NutritionEntry.delete_all
      end

      test "ingests a single nutrition entry" do
        assert_difference "NutritionEntry.count", 1 do
          post api_v1_nutrition_index_url, params: {
            taken_at: "2026-09-29T13:30:00-06:00", carbs_g: 45, calories_kcal: 620,
            meal_type: "lunch", source: "Zepp Food Log", client_id: "hc:meal1"
          }, as: :json
        end
        assert_response :created
        assert_equal 1, JSON.parse(response.body).dig("ingested")

        entry = NutritionEntry.last
        assert_equal 45, entry.carbs_g
        assert_equal "lunch", entry.meal_type
      end

      test "accepts kcal-only entries" do
        post api_v1_nutrition_index_url, params: {
          taken_at: "2026-09-29T10:00:00-06:00", calories_kcal: 120, client_id: "hc:snack"
        }, as: :json

        assert_response :created
        assert_equal 120, NutritionEntry.last.calories_kcal
      end

      test "rejects entries with neither carbs nor kcal" do
        post api_v1_nutrition_index_url, params: {
          taken_at: "2026-09-29T10:00:00-06:00", client_id: "hc:empty"
        }, as: :json

        assert_response :unprocessable_content
        assert_equal 0, NutritionEntry.count
      end

      test "mixed batch: fresh valid rows ingest, duplicate rows are skipped" do
        NutritionEntry.create!(taken_at: 1.hour.ago, carbs_g: 10, client_id: "hc:existing")

        post api_v1_nutrition_index_url, params: [
          { taken_at: "2026-09-29T13:30:00-06:00", carbs_g: 45, client_id: "hc:existing" }, # dup → skip
          { taken_at: "2026-09-29T19:00:00-06:00", carbs_g: 30, client_id: "hc:fresh" },    # new → insert
        ], as: :json

        assert_response :created
        body = JSON.parse(response.body)
        assert_equal 1, body.dig("ingested")
        assert_equal 2, body.dig("received")
        assert_equal 2, NutritionEntry.count
      end

      test "rejects unknown meal types" do
        post api_v1_nutrition_index_url, params: {
          taken_at: "2026-09-29T10:00:00-06:00", carbs_g: 10, meal_type: "brunch",
          client_id: "hc:brunch"
        }, as: :json

        assert_response :unprocessable_content
        assert_equal 0, NutritionEntry.count
      end

      test "is idempotent on client_id (first wins)" do
        payload = { taken_at: "2026-09-29T13:30:00-06:00", carbs_g: 45, client_id: "hc:same" }

        post api_v1_nutrition_index_url, params: payload, as: :json
        assert_response :created

        # Retry with the same client_id: still 201, ingested 0, no dup row,
        # original values untouched.
        post api_v1_nutrition_index_url, params: payload.merge(carbs_g: 999), as: :json
        assert_response :created

        assert_equal 1, NutritionEntry.count
        assert_equal 45, NutritionEntry.last.carbs_g
      end

      test "index returns ascending entries and clamps hours" do
        NutritionEntry.create!(taken_at: 400.hours.ago, carbs_g: 10, client_id: "hc:old")
        NutritionEntry.create!(taken_at: 2.hours.ago, carbs_g: 30, client_id: "hc:new")

        # Default 24 h window excludes the 400-hour-old entry.
        get api_v1_nutrition_index_url, as: :json
        nutrition = JSON.parse(response.body).dig("nutrition")
        assert_equal 1, nutrition.size
        assert_equal "hc:new", nutrition.first["client_id"]

        # Max clamp 336 h still excludes it.
        get api_v1_nutrition_index_url(params: { hours: 1000 }), as: :json
        assert_equal 1, JSON.parse(response.body).dig("nutrition").size
      end
    end
  end
end
