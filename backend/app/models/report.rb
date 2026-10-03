# All math behind GET /report (slice 7, per docs/ADR-003-activity-nutrition.md).
#
# Computes the ADA Standard CGM Report core metrics, the AGP-style 24-hour
# median profile with percentile band, the per-day context table, and the
# A1C/GMI history from live table data. No rollups — at personal scale this
# is instant. Display unit is mg/dL throughout.
class Report
  # Consensus CGM targets (mg/dL) with their goal percentages.
  TARGETS = {
    tir: { pct: 70.0, label: "70–180 > 70%" },
    tar_l1: { pct: 25.0, label: ">180 < 25%" },
    tar_l2: { pct: 5.0, label: ">250 < 5%" },
    tbr_l1: { pct: 4.0, label: "<70 < 4%" },
    tbr_l2: { pct: 1.0, label: "<54 < 1%" }
  }.freeze

  attr_reader :days, :zone, :start_date, :end_date

  def initialize(days)
    @days = days
    @zone = Setting.instance.timezone
    @end_date = Date.current.in_time_zone(@zone).to_date
    @start_date = @end_date - (days - 1)
  end

  # ---- Core metrics -------------------------------------------------------

  def readings
    @readings ||= GlucoseReading.in_local_days(@zone, @days).to_a
  end

  def readings_count
    readings.size
  end

  # Days inside the window with at least one reading. Days with no CGM data
  # are absent, not zero.
  def days_of_data
    @days_of_data ||= readings.map { |r| r.time.in_time_zone(@zone).to_date }.uniq.size
  end

  # % time active: readings over expected readings (288/day at 5-minute
  # sampling) across the days of data.
  def pct_time_active
    expected = days_of_data * 288.0
    return 0.0 if expected.zero?

    (readings_count / expected * 100).round(1)
  end

  def mean_glucose
    return nil if readings.empty?

    (readings.sum(&:sgv).fdiv(readings_count)).round(1)
  end

  # GMI% = 3.31 + 0.02392 × mean glucose (mg/dL).
  def gmi
    m = mean_glucose
    return nil if m.nil?

    (3.31 + 0.02392 * m).round(1)
  end

  # CV% = sd / mean × 100; goal ≤ 36%.
  def cv
    return nil if readings.empty?

    mean = readings.sum(&:sgv).fdiv(readings_count)
    variance = readings.sum { |r| (r.sgv - mean) ** 2 }.fdiv(readings_count)
    (Math.sqrt(variance) / mean * 100).round(1)
  end

  def time_in_range
    @time_in_range ||= begin
      counts = { below_l2: 0, below_l1: 0, in_range: 0, above_l1: 0, above_l2: 0 }
      readings.each do |r|
        sgv = r.sgv
        if sgv < 54 then counts[:below_l2] += 1
        elsif sgv < 70 then counts[:below_l1] += 1
        elsif sgv > 250 then counts[:above_l2] += 1
        elsif sgv > 180 then counts[:above_l1] += 1
        else counts[:in_range] += 1
        end
      end
      n = readings_count
      n.zero? ? counts.transform_values { 0.0 } : counts.transform_values { |c| (c * 100.0 / n).round(1) }
    end
  end

  # ---- AGP 24-hour profile ------------------------------------------------

  # All days collapsed into one 24-hour profile, bucketed by local time of
  # day in 15-minute slots. Each slot gets p10/p25/median/p75/p90.
  def agp_profile
    @agp_profile ||= begin
      buckets = Array.new(96) { [] }
      readings.each do |r|
        local = r.time.in_time_zone(@zone)
        buckets[local.hour * 4 + local.min / 15] << r.sgv
      end
      buckets.map { |values| percentiles(values) }
    end
  end

  # ---- Per-day context table ---------------------------------------------

  def day_rows
    @day_rows ||= begin
      day_sql = Dose.local_day_sql(@zone)

      insulin = Dose.in_local_days(@zone, @days)
        .group(Arel.sql(day_sql))
        .order(Arel.sql(day_sql))
        .pluck(
          Arel.sql(day_sql),
          Arel.sql("sum(units) filter (where kind = #{Dose.kinds.fetch('fast')})"),
          Arel.sql("sum(units) filter (where kind = #{Dose.kinds.fetch('slow')})")
        )
      carbs = NutritionEntry.in_local_days(@zone, @days)
        .group(Arel.sql(NutritionEntry.day_sql(@zone)))
        .pluck(
          Arel.sql(NutritionEntry.day_sql(@zone)),
          Arel.sql("sum(carbs_g)"),
          Arel.sql("sum(calories_kcal)")
        )
      exercise = ActivitySession.in_local_days(@zone, @days)
        .group(Arel.sql(ActivitySession.day_sql(@zone)))
        .pluck(Arel.sql(ActivitySession.day_sql(@zone)), Arel.sql("sum(minutes)"))

      by_date = Hash.new do |h, k|
        h[k] = { date: k.to_s, fast_units: 0, slow_units: 0, total_units: 0,
                 carbs_g: 0, calories_kcal: 0, exercise_min: 0 }
      end
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

      by_date.values.sort_by { |r| r[:date] }
    end
  end

  # ---- A1C history ---------------------------------------------------------

  def a1c_history
    @a1c_history ||= A1cEntry.order(:measured_on)
      .map { |e| { measured_on: e.measured_on.to_s, value: e.value.to_f } }
  end

  # GMI per local day from average glucose — the trend line that runs between
  # lab points in the A1C chart. Covers the full reading history (bounded by
  # 180 days) so old lab points keep context.
  def gmi_trend
    @gmi_trend ||= begin
      day_sql = GlucoseReading.day_sql(@zone)
      GlucoseReading
        .where(time: 180.days.ago..)
        .group(Arel.sql(day_sql))
        .order(Arel.sql(day_sql))
        .pluck(Arel.sql(day_sql), Arel.sql("avg(sgv)"))
        .map do |day, avg|
          { date: day.to_s, gmi: (3.31 + 0.02392 * avg.to_f).round(1) }
        end
    end
  end

  # ---- Day detail ----------------------------------------------------------

  # One day's glucose curve plus the context markers that land on it.
  def day_detail(date_string)
    day = parse_local_date(date_string)
    return nil unless day

    local = ->(t) { t.in_time_zone(@zone) }
    doses = Dose.in_local_days(@zone, @days)
      .select { |d| local.call(d.effective_time).to_date == day }
      .sort_by(&:effective_time)
    meals = NutritionEntry.in_local_days(@zone, @days)
      .select { |n| local.call(n.taken_at).to_date == day }
      .sort_by(&:taken_at)
    workouts = ActivitySession.in_local_days(@zone, @days)
      .select { |w| local.call(w.started_at).to_date == day }
      .sort_by(&:started_at)
    day_glucose = readings.select { |r| local.call(r.time).to_date == day }

    {
      date: day,
      glucose: day_glucose,
      doses: doses,
      meals: meals,
      workouts: workouts
    }
  end

  # Returns the parsed date if it is inside the report window, else nil.
  def parse_local_date(string)
    day = Date.parse(string.to_s) rescue nil
    return nil unless day
    return nil if day < @start_date || day > @end_date

    day
  end

  private

  # Linear-interpolation percentiles on a small array of sgv values.
  def percentiles(values)
    return { p10: nil, p25: nil, p50: nil, p75: nil, p90: nil, n: 0 } if values.empty?

    sorted = values.sort
    {
      p10: percentile(sorted, 10),
      p25: percentile(sorted, 25),
      p50: percentile(sorted, 50),
      p75: percentile(sorted, 75),
      p90: percentile(sorted, 90),
      n: sorted.size
    }
  end

  def percentile(sorted, p)
    return nil if sorted.empty?

    k = (p / 100.0) * (sorted.size - 1)
    f = k.floor
    c = k.ceil
    if f == c
      sorted[f].to_f
    else
      sorted[f] + (sorted[c] - sorted[f]) * (k - f)
    end.round(1)
  end
end
