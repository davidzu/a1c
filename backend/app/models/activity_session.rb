class ActivitySession < ApplicationRecord
  validates :started_at, :ended_at, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :calories_kcal, :avg_hr, :max_hr,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  validates :client_id, presence: true, uniqueness: true

  scope :recent, -> { order(started_at: :desc) }

  def self.last_hours(hours)
    where(ended_at: hours.hours.ago..).order(started_at: :asc)
  end

  private

  def ends_after_start
    return if started_at.blank? || ended_at.blank?

    errors.add(:ended_at, "must be after started_at") if ended_at <= started_at
  end
end
