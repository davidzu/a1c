class NutritionEntry < ApplicationRecord
  validates :taken_at, presence: true
  validates :carbs_g, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :calories_kcal, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :meal_type, inclusion: { in: %w[unknown breakfast lunch dinner snack] }, allow_nil: true

  validate :at_least_one_value

  validates :client_id, presence: true, uniqueness: true

  scope :recent, -> { order(taken_at: :desc) }

  def self.last_hours(hours)
    where(taken_at: hours.hours.ago..).order(taken_at: :asc)
  end

  private

  def at_least_one_value
    return if carbs_g.present? || calories_kcal.present?

    errors.add(:base, "must have carbs_g or calories_kcal")
  end
end
