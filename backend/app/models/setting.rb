class Setting < ApplicationRecord
  TIMEZONE_PATTERN = /\A[A-Za-z_+\-][A-Za-z0-9_+\-\/]*\z/

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

  private

  def timezone_exists
    Time.find_zone(timezone) or errors.add(:timezone, "unknown IANA zone")
  end
end
