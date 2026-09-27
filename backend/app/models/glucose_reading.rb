class GlucoseReading < ApplicationRecord
  validates :sgv, numericality: { only_integer: true, greater_than: 0, less_than: 2000 }
  validates :time, presence: true

  scope :recent, -> { order(time: :desc) }

  def self.last_hours(hours)
    where(time: hours.hours.ago..).order(time: :asc)
  end

  def mmol_l
    sgv.fdiv(18).round(1)
  end
end
