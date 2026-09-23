class Dose < ApplicationRecord
  enum :kind, %i[fast slow], validate: true

  validates :units, numericality: { only_integer: true, greater_than: 0 }

  scope :recent, -> { order(created_at: :desc).limit(50) }

  def self.daily_totals
    fast = Dose.kinds.fetch("fast")
    slow = Dose.kinds.fetch("slow")
    Dose
      .group(Arel.sql("date(created_at)"))
      .order(Arel.sql("date(created_at)"))
      .pluck(
        Arel.sql("date(created_at)"),
        Arel.sql("sum(units) filter (where kind = #{fast})"),
        Arel.sql("sum(units) filter (where kind = #{slow})")
      )
      .map do |date, fast_total, slow_total|
        {
          date: date.to_s,
          fast_units: fast_total.to_i,
          slow_units: slow_total.to_i,
          total_units: fast_total.to_i + slow_total.to_i
        }
      end
  end
end
