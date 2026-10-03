class ActivitySession < ApplicationRecord
  validates :started_at, :ended_at, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :calories_kcal, :avg_hr, :max_hr,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  validates :client_id, presence: true, uniqueness: true

  scope :recent, -> { order(started_at: :desc) }

  # Local-day bucket expression on the session's start, same convention as
  # doses and nutrition (midnight in the configured zone — never UTC).
  def self.day_sql(zone)
    quoted = connection.quote(zone)
    <<~SQL.squish
      date((started_at AT TIME ZONE 'UTC') AT TIME ZONE #{quoted})
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
    where(ended_at: hours.hours.ago..).order(started_at: :asc)
  end

  private

  def ends_after_start
    return if started_at.blank? || ended_at.blank?

    errors.add(:ended_at, "must be after started_at") if ended_at <= started_at
  end
end
