class Dose < ApplicationRecord
  enum :kind, %i[fast slow], validate: true

  validates :units, numericality: { only_integer: true, greater_than: 0 }
  validates :client_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(created_at: :desc).limit(50) }

  # The moment that counts for the graph: the real injection time when the
  # client recorded it (offline sync), otherwise the server receive time.
  def effective_time
    taken_at || created_at
  end

  # One row per local day (per the configured timezone), with fast/slow splits.
  # Day boundary is midnight in Setting.instance.timezone — never UTC.
  def self.daily_totals
    zone = Setting.instance.timezone
    fast = Dose.kinds.fetch("fast")
    slow = Dose.kinds.fetch("slow")
    day_sql = local_day_sql(zone)
    Dose
      .group(Arel.sql(day_sql))
      .order(Arel.sql(day_sql))
      .pluck(
        Arel.sql(day_sql),
        Arel.sql("sum(units) filter (where kind = #{fast})"),
        Arel.sql("sum(units) filter (where kind = #{slow})")
      )
      .map do |day, fast_total, slow_total|
        {
          date: day.to_s,
          fast_units: fast_total.to_i,
          slow_units: slow_total.to_i,
          total_units: fast_total.to_i + slow_total.to_i
        }
      end
  end

  # Postgres: shift the UTC timestamp into the configured zone, take its date.
  # `AT TIME ZONE 'UTC'` first makes the timestamptz naive-UTC, the second call
  # renders it in the target zone. Rails stores timestamps in UTC.
  # (No "AS day" alias — Postgres doesn't allow aliases in GROUP BY.)
  def self.local_day_sql(zone)
    quoted_zone = connection.quote(zone)
    <<~SQL.squish
      date(
        (coalesce(taken_at, created_at) AT TIME ZONE 'UTC') AT TIME ZONE #{quoted_zone}
      )
    SQL
  end

  # Doses on local days within the last N local days (inclusive of today).
  def self.in_local_days(zone, days)
    where(
      "#{local_day_sql(zone)} BETWEEN ? AND ?",
      (days - 1).days.ago.in_time_zone(zone).to_date,
      Time.current.in_time_zone(zone).to_date
    )
  end
end
