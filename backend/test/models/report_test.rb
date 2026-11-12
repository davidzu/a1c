require "test_helper"

class ReportTest < ActiveSupport::TestCase
  setup do
    GlucoseReading.delete_all
    Setting.delete_all
  end

  test "pct_time_active is independent of the uploader's sampling rate" do
    zone = Setting.instance.timezone
    noon = Time.current.in_time_zone(zone).change(hour: 12)

    # Two hours at xDrip's 5-minute cadence: 24 five-minute buckets.
    24.times { |i| GlucoseReading.create!(sgv: 120, time: noon - (i * 5).minutes) }
    five_min = Report.new(1).pct_time_active

    GlucoseReading.delete_all

    # The same wall-clock span at Juggluco's 1-minute cadence (116 points
    # across the same 115 minutes): the same buckets, not 5× the count.
    116.times { |i| GlucoseReading.create!(sgv: 120, time: noon - i.minutes) }
    one_min = Report.new(1).pct_time_active

    assert_in_delta five_min, one_min, 0.05
    assert_operator one_min, :<=, 100.0
  end

  test "pct_time_active never exceeds 100 with a full day of 1-minute data" do
    zone = Setting.instance.timezone
    start = Time.current.in_time_zone(zone).beginning_of_day
    now = Time.current

    rows = 1440.times.map do |i|
      { sgv: 120, time: start + i.minutes, created_at: now, updated_at: now }
    end
    GlucoseReading.insert_all!(rows)

    pct = Report.new(1).pct_time_active

    assert_operator pct, :<=, 100.0
    assert_in_delta 100.0, pct, 0.5
  end
end
