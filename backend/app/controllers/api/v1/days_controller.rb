module Api
  module V1
    # The unified day table: one row per local day with insulin, carbs,
    # kcal, and exercise minutes. Powers the app's day bars and the report.
    # Day boundary is midnight in settings.timezone — never UTC.
    class DaysController < ApplicationController
      MAX_DAYS = 180

      def index
        days = params[:days].present? ? [[params[:days].to_i, 1].max, MAX_DAYS].min : 30
        render json: { days: day_rows(days) }
      end

      private

      def day_rows(limit)
        zone = Setting.instance.timezone
        day_sql = Dose.local_day_sql(zone)

        insulin = Dose
          .group(Arel.sql(day_sql))
          .order(Arel.sql(day_sql))
          .pluck(
            Arel.sql(day_sql),
            Arel.sql("sum(units) filter (where kind = #{Dose.kinds.fetch('fast')})"),
            Arel.sql("sum(units) filter (where kind = #{Dose.kinds.fetch('slow')})")
          )
        carbs = NutritionEntry
          .group(Arel.sql(nutrition_day_sql(zone)))
          .pluck(Arel.sql(nutrition_day_sql(zone)), Arel.sql("sum(carbs_g)"), Arel.sql("sum(calories_kcal)"))
        exercise = ActivitySession
          .group(Arel.sql(activity_day_sql(zone)))
          .pluck(Arel.sql(activity_day_sql(zone)), Arel.sql("sum(minutes)"))

        by_date = Hash.new { |h, k| h[k] = { date: k.to_s, fast_units: 0, slow_units: 0, total_units: 0, carbs_g: 0, calories_kcal: 0, exercise_min: 0 } }
        insulin.each do |day, fast, slow|
          row = by_date[day]
          row[:fast_units] = fast.to_i
          row[:slow_units] = slow.to_i
          row[:total_units] = row[:fast_units] + row[:slow_units]
        end
        carbs.each do |day, c, kcal|
          row = by_date[day]
          row[:carbs_g] = c.to_i
          row[:calories_kcal] = kcal.to_i
        end
        exercise.each do |day, minutes|
          by_date[day][:exercise_min] = minutes.to_i
        end

        by_date.values.last(limit).sort_by { |r| r[:date] }
      end

      # Nutrition and activity use the same local-day bucketing as doses,
      # each on their own timestamp column.
      def nutrition_day_sql(zone)
        quoted = NutritionEntry.connection.quote(zone)
        <<~SQL.squish
          date((taken_at AT TIME ZONE 'UTC') AT TIME ZONE #{quoted})
        SQL
      end

      def activity_day_sql(zone)
        quoted = ActivitySession.connection.quote(zone)
        <<~SQL.squish
          date((started_at AT TIME ZONE 'UTC') AT TIME ZONE #{quoted})
        SQL
      end
    end
  end
end
