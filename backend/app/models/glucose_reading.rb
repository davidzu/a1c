class GlucoseReading < ApplicationRecord
  validates :sgv, numericality: { only_integer: true, greater_than: 0, less_than: 2000 }
  validates :time, presence: true

  scope :recent, -> { order(time: :desc) }

  def self.last_hours(hours)
    where(time: hours.hours.ago..).order(time: :asc)
  end

  # Readings whose local day (configured zone) falls within the last N local
  # days, inclusive of today. Used by the doctor report.
  def self.in_local_days(zone, days)
    where(
      "#{day_sql(zone)} BETWEEN ? AND ?",
      (days - 1).days.ago.in_time_zone(zone).to_date,
      Time.current.in_time_zone(zone).to_date
    )
  end

  # Postgres local-day expression over `time`, same convention as doses.
  def self.day_sql(zone)
    quoted_zone = connection.quote(zone)
    <<~SQL.squish
      date((time AT TIME ZONE 'UTC') AT TIME ZONE #{quoted_zone})
    SQL
  end

  def mmol_l
    sgv.fdiv(18).round(1)
  end
end
