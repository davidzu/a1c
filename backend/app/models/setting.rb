class Setting < ApplicationRecord
  validates :fast_name, presence: true
  validates :slow_name, presence: true
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :last_a1c, numericality: { greater_than: 0 }, allow_nil: true

  def self.instance
    first || create!
  end
end
