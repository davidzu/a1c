class Dose < ApplicationRecord
  enum :kind, %i[fast slow], validate: true

  validates :units, numericality: { only_integer: true, greater_than: 0 }

  scope :recent, -> { order(created_at: :desc).limit(50) }

  def self.daily_totals
    group("date(created_at)")
      .order(Arel.sql("date(created_at)"))
      .sum(:units)
      .map { |date, total| { date: date.to_s, total_units: total } }
  end
end
