# Server-side SVG builders for the doctor report (slice 7).
# Pure string builders — no JS, printable, inline in the ERB.
module ReportHelper
  # Navigation stays on whichever path served the page: /doctor-dashboard
  # keeps its clean, token-free URLs, and an older /report?token=… link keeps
  # working without the token falling off on the next click.
  def report_link(days: nil, day: nil)
    query = { days: days, day: day, token: params[:token].presence }.compact
    query.empty? ? request.path : "#{request.path}?#{query.to_query}"
  end

  # Y scale factory for mg/dL charts: maps mg/dL → pixel y.
  def self.y_scale(height, top_pad, bottom_pad, lo = 0, hi = 350)
    scale = (height - top_pad - bottom_pad).to_f / (hi - lo)
    ->(mgdl) { top_pad + (hi - mgdl) * scale }
  end

  # AGP-style 24-hour profile: 96 slots of p10/p25/median/p75/p90.
  # Draws the 10–90 band, the 25–75 band, and the median line.
  def self.agp_svg(profile, width: 720, height: 260)
    top = 14
    bottom = 24
    left = 34
    right = 10
    y = y_scale(height, top, bottom, 0, 350)
    slot_w = (width - left - right).to_f / profile.size

    svg = +"<svg viewBox=\"0 0 #{width} #{height}\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"AGP 24-hour glucose profile\">"
    # target band 70-180
    svg << band(left, width - right, y.call(180), y.call(70), "#4ade80", 0.12)
    # p10-p90
    svg << area_path(profile, slot_w, left, bottom, y, :p10, :p90, "#7c3aed", 0.10)
    # p25-p75
    svg << area_path(profile, slot_w, left, bottom, y, :p25, :p75, "#7c3aed", 0.22)
    # median line
    svg << line_path(profile, slot_w, left, y, :p50, "#7c3aed", 2)
    # x axis labels (local hours)
    [ 0, 6, 12, 18, 23 ].each do |h|
      x = left + h * 4 * slot_w + slot_w / 2
      svg << %(<text x="#{x.round(1)}" y="#{height - 8}" font-size="9" fill="#999" text-anchor="middle">#{format("%02d", h)}:00</text>)
    end
    # y grid
    [ 70, 180, 250 ].each do |mgdl|
      yy = y.call(mgdl).round(1)
      svg << %(<line x1="#{left}" y1="#{yy}" x2="#{width - right}" y2="#{yy}" stroke="#e5e5e5" stroke-width="1"/>)
      svg << %(<text x="#{left - 4}" y="#{yy + 3}" font-size="9" fill="#999" text-anchor="end">#{mgdl}</text>)
    end
    svg << "</svg>"
    svg.html_safe
  end

  # Single-day glucose curve with markers: doses (triangles), meals (dots),
  # workouts (translucent bands). data = {glucose:, doses:, meals:, workouts:}
  def self.day_svg(data, zone:, width: 720, height: 260)
    top = 14
    bottom = 24
    left = 34
    right = 10
    y = y_scale(height, top, bottom, 0, 350)
    points = data[:glucose]
    x = ->(t) { left + (t.hour * 60 + t.min).fdiv(1440) * (width - left - right) }
    local = ->(t) { t.in_time_zone(zone) }

    svg = +"<svg viewBox=\"0 0 #{width} #{height}\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"Day glucose curve\">"
    svg << band(left, width - right, y.call(180), y.call(70), "#4ade80", 0.12)
    # workout bands first (behind everything)
    data[:workouts].each do |w|
      x1 = x.call(local.call(w.started_at))
      x2 = x.call(local.call(w.ended_at))
      svg << %(<rect x="#{x1.round(1)}" y="#{top}" width="#{(x2 - x1).round(1)}" height="#{height - top - bottom}" fill="#60a5fa" opacity="0.18"/>)
    end
    # glucose polyline
    coords = points.map { |r| "#{x.call(local.call(r.time)).round(1)},#{y.call(r.sgv).round(1)}" }
    svg << %(<polyline points="#{coords.join(" ")}" fill="none" stroke="#7c3aed" stroke-width="1.6"/>) if coords.size > 1
    # meal dots
    data[:meals].each do |m|
      svg << %(<circle cx="#{x.call(local.call(m.taken_at)).round(1)}" cy="#{y.call(0) - 2}" r="4" fill="#f59e0b"/>)
    end
    # dose triangles: fast up, slow down
    data[:doses].each do |d|
      xx = x.call(local.call(d.effective_time))
      if d.fast?
        svg << %(<polygon points="#{xx.round(1)},#{y.call(350) + 2} #{xx.round(1) - 5},#{y.call(350) + 12} #{xx.round(1) + 5},#{y.call(350) + 12}" fill="#ec4899"/>)
      else
        svg << %(<polygon points="#{xx.round(1)},#{height - bottom - 2} #{xx.round(1) - 5},#{height - bottom - 12} #{xx.round(1) + 5},#{height - bottom - 12}" fill="#8b5cf6"/>)
      end
    end
    [ 0, 6, 12, 18, 23 ].each do |h|
      xx = left + h.fdiv(24) * (width - left - right)
      svg << %(<text x="#{xx.round(1)}" y="#{height - 8}" font-size="9" fill="#999" text-anchor="middle">#{format("%02d", h)}:00</text>)
    end
    [ 70, 180, 250 ].each do |mgdl|
      yy = y.call(mgdl).round(1)
      svg << %(<line x1="#{left}" y1="#{yy}" x2="#{width - right}" y2="#{yy}" stroke="#e5e5e5" stroke-width="1"/>)
      svg << %(<text x="#{left - 4}" y="#{yy + 3}" font-size="9" fill="#999" text-anchor="end">#{mgdl}</text>)
    end
    svg << "</svg>"
    svg.html_safe
  end

  # A1C history: the GMI trend from CGM means, with each lab A1C drawn as a
  # horizontal reference line across the graph. The window starts at the last
  # lab date (so the lab value and the trend share one axis) and runs to the
  # report's end date; with no lab on file it starts at the report window.
  def self.a1c_svg(history, trend, start_date:, end_date:, width: 720, height: 220)
    return "".html_safe if history.empty? && trend.empty?

    top = 14
    bottom = 24
    left = 46 # room for the rotated axis title
    right = 12

    t0 = start_date
    t1 = end_date
    points = trend.select do |t|
      date = Date.parse(t[:date])
      date >= t0 && date <= t1
    end

    all = history.map { |h| h[:value] } + points.map { |t| t[:gmi] }
    lo = [ (all.min - 0.5), 4.0 ].max.floor
    hi = (all.max + 0.5).ceil
    y = y_scale(height, top, bottom, lo, hi)
    span = [ (t1 - t0).to_i, 1 ].max
    x = ->(d) { left + (d - t0).fdiv(span) * (width - left - right) }

    svg = +"<svg viewBox=\"0 0 #{width} #{height}\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"A1C history with GMI trend\">"

    # y grid: one line per percentage point, labelled
    (lo..hi).each do |value|
      yy = y.call(value).round(1)
      svg << %(<line x1="#{left}" y1="#{yy}" x2="#{width - right}" y2="#{yy}" stroke="#ececec" stroke-width="1"/>)
      svg << %(<text x="#{left - 4}" y="#{yy + 3}" font-size="9" fill="#999" text-anchor="end">#{value}</text>)
    end

    # GMI trend from the daily CGM mean
    coords = points.map { |t| "#{x.call(Date.parse(t[:date])).round(1)},#{y.call(t[:gmi]).round(1)}" }
    svg << %(<polyline points="#{coords.join(" ")}" fill="none" stroke="#a78bfa" stroke-width="1.4" stroke-dasharray="3 2"/>) if coords.size > 1

    # lab A1C as a line along the graph, labelled at the right edge
    history.each do |h|
      value = h[:value]
      yy = y.call(value).round(1)
      svg << %(<line x1="#{left}" y1="#{yy}" x2="#{width - right}" y2="#{yy}" stroke="#7c3aed" stroke-width="1.6" stroke-dasharray="7 3"/>)
      svg << %(<text x="#{width - right - 2}" y="#{yy - 4}" font-size="9" fill="#7c3aed" text-anchor="end">lab #{value}%</text>)
    end

    # y axis title + explanation, rotated along the left edge
    svg << %(<text transform="translate(11, #{height / 2}) rotate(-90)" font-size="9" fill="#6b6b6b" text-anchor="middle">A1C / GMI (%)</text>)

    # x axis ends
    svg << %(<text x="#{left}" y="#{height - 8}" font-size="9" fill="#999">#{t0}</text>)
    svg << %(<text x="#{width - right}" y="#{height - 8}" font-size="9" fill="#999" text-anchor="end">#{t1}</text>)
    svg << "</svg>"
    svg.html_safe
  end

  # ---- internals -----------------------------------------------------------

  def self.band(x1, x2, y_top, y_bottom, color, opacity)
    %(<rect x="#{x1.round(1)}" y="#{y_top.round(1)}" width="#{(x2 - x1).round(1)}" height="#{(y_bottom - y_top).round(1)}" fill="#{color}" opacity="#{opacity}"/>)
  end

  # Filled band between two percentile keys across the profile.
  def self.area_path(profile, slot_w, left, bottom, y, lo_key, hi_key, color, opacity)
    upper = []
    lower = []
    profile.each_with_index do |slot, i|
      next if slot[hi_key].nil?

      x = left + i * slot_w + slot_w / 2
      upper << "#{x.round(1)},#{y.call(slot[hi_key]).round(1)}"
      lower << "#{x.round(1)},#{y.call(slot[lo_key]).round(1)}"
    end
    return "" if upper.empty?

    path = "M" + upper.join(" L") + " L" + lower.reverse.join(" L") + " Z"
    %(<path d="#{path}" fill="#{color}" opacity="#{opacity}"/>)
  end

  def self.line_path(profile, slot_w, left, y, key, color, stroke)
    coords = []
    profile.each_with_index do |slot, i|
      next if slot[key].nil?

      x = left + i * slot_w + slot_w / 2
      coords << "#{x.round(1)},#{y.call(slot[key]).round(1)}"
    end
    return "" if coords.empty?

    %(<polyline points="#{coords.join(" ")}" fill="none" stroke="#{color}" stroke-width="#{stroke}"/>)
  end
end
