class NutritionEntry < ApplicationRecord
  validates :taken_at, presence: true
  validates :carbs_g, numericality: { greater_than: 0 }, allow_nil: true
  validates :calories_kcal, numericality: { greater_than: 0 }, allow_nil: true
  validates :meal_type, inclusion: { in: %w[unknown breakfast lunch dinner snack] }, allow_nil: true

  validate :at_least_one_value

  validates :client_id, presence: true, uniqueness: true

  scope :recent, -> { order(taken_at: :desc) }

  # Local-day bucket expression, shared by the app's day bars and the doctor
  # report. Day boundary is midnight in the configured zone — never UTC.
  def self.day_sql(zone)
    quoted = connection.quote(zone)
    <<~SQL.squish
      date((taken_at AT TIME ZONE 'UTC') AT TIME ZONE #{quoted})
    SQL
  end

  # Rows on local days within the last N local days (inclusive of today).
  def self.in_local_days(zone, days)
    where(
      "#{day_sql(zone)} BETWEEN ? AND ?",
      (days - 1).days.ago.in_time_zone(zone).to_date,
      Time.current.in_time_zone(zone).to_date
    )
  end

  def self.last_hours(hours)
    where(taken_at: hours.hours.ago..).order(taken_at: :asc)
  end

  private

  def at_least_one_value
    return if carbs_g.present? || calories_kcal.present?

    errors.add(:base, "must have carbs_g or calories_kcal")
  end
end
