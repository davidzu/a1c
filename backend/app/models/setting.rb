class Setting < ApplicationRecord
  TIMEZONE_PATTERN = /\A[A-Za-z_+\-][A-Za-z0-9_+\-\/]*\z/

  # A report window cannot be armed for longer than a week. The point of the
  # switch is that the page is dark by default and only briefly readable.
  REPORT_MAX_MINUTES = 7 * 24 * 60

  validates :fast_name, presence: true
  validates :slow_name, presence: true
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :last_a1c, numericality: { greater_than: 0 }, allow_nil: true
  validates :timezone, presence: true,
                       format: { with: TIMEZONE_PATTERN, message: "must be an IANA zone name" }

  validate :timezone_exists, if: -> { timezone.present? && timezone.match?(TIMEZONE_PATTERN) }

  def self.instance
    first || create!
  end

  # ---- Doctor report access (see db/migrate/20261124000000) ----------------

  # The report is closed unless a window is currently armed. This is the
  # single source of truth for GET /report.
  def report_armed?
    report_access_until.present? && report_access_until.future?
  end

  def report_minutes_left
    return 0 unless report_armed?

    ((report_access_until - Time.current) / 60).ceil
  end

  # DB token wins (rotated, no restart needed); the env var is the bootstrap
  # value so the deploy that shipped this keeps its existing URL working.
  def effective_report_token
    report_token.presence || ENV["REPORT_TOKEN"].presence
  end

  def arm_report!(minutes)
    minutes = minutes.to_i.clamp(1, REPORT_MAX_MINUTES)
    update!(report_access_until: minutes.minutes.from_now)
  end

  def disarm_report!
    update!(report_access_until: nil)
  end

  def rotate_report_token!
    update!(report_token: SecureRandom.hex(24))
  end

  private

  def timezone_exists
    Time.find_zone(timezone) or errors.add(:timezone, "unknown IANA zone")
  end
end
