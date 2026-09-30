class A1cEntry < ApplicationRecord
  validates :measured_on, presence: true, uniqueness: true
  validates :value, numericality: { greater_than: 0 }
end
