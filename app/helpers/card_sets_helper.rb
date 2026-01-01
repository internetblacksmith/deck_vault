module CardSetsHelper
  def rarity_class(rarity)
    case rarity&.downcase
    when "common"
      "rarity-common"
    when "uncommon"
      "rarity-uncommon"
    when "rare"
      "rarity-rare"
    when "mythic"
      "rarity-mythic"
    else
      "bg-gray-200 text-gray-700"
    end
  end

  # Generate sortable collector number that handles:
  # - Pure numbers: "1", "42", "286"
  # - Numbers with suffixes: "297a", "297b", "363★"
  # - Special characters: "★", "†"
  # Format: zero-padded number (6 digits) + suffix for proper string sorting
  def sortable_collector_number(collector_number)
    return "999999" if collector_number.blank?

    # Extract numeric prefix and suffix
    # Match: optional digits, then optional non-digits
    match = collector_number.to_s.match(/^(\d*)(.*)$/)
    num_part = match[1].presence || "999999"
    suffix = match[2].to_s.downcase

    # Pad number to 6 digits, append suffix
    format("%06d%s", num_part.to_i, suffix)
  end

  # Calculate color identity sort value (WUBRG order)
  def color_sort_value(mana_cost)
    mana = mana_cost || ""
    colors = []
    colors << "W" if mana.include?("{W}")
    colors << "U" if mana.include?("{U}")
    colors << "B" if mana.include?("{B}")
    colors << "R" if mana.include?("{R}")
    colors << "G" if mana.include?("{G}")

    if colors.empty?
      "6-Colorless"
    elsif colors.length > 1
      "7-Multi"
    else
      case colors.first
      when "W" then "1-White"
      when "U" then "2-Blue"
      when "B" then "3-Black"
      when "R" then "4-Red"
      when "G" then "5-Green"
      end
    end
  end

  # Calculate mana value (converted mana cost)
  def mana_value(mana_cost)
    mana = mana_cost || ""
    mana.scan(/\{([^}]+)\}/).flatten.sum do |symbol|
      if symbol.match?(/^\d+$/)
        symbol.to_i
      elsif symbol == "X"
        0
      else
        1
      end
    end
  end

  # Rarity sort order value
  def rarity_sort_value(rarity)
    { "common" => 1, "uncommon" => 2, "rare" => 3, "mythic" => 4 }[rarity] || 0
  end

  # Format collector number like on physical cards: SET001, SET001a
  # Examples: "1" -> "TLA001", "297a" -> "TLA297a"
  def formatted_collector_number(collector_number, set_code)
    return "" if collector_number.blank?

    # Extract numeric part and suffix (e.g., "297a" -> "297", "a")
    match = collector_number.to_s.match(/^(\d+)(.*)$/)
    return "#{set_code.upcase}#{collector_number}" unless match

    num_part = match[1].to_i
    suffix = match[2].to_s

    # Format: SET + zero-padded number (3 digits) + suffix
    "#{set_code.upcase}#{format('%03d', num_part)}#{suffix}"
  end

  # Calculate which binder page a card would be on based on its position
  # Position is 1-indexed (first card is position 1)
  def calculate_binder_page(position, cards_per_page)
    return 1 if position <= 0 || cards_per_page <= 0

    ((position - 1) / cards_per_page) + 1
  end

  # Returns a color for percentage values: red (0%) -> yellow (50%) -> green (100%)
  def percentage_color(percent)
    percent = percent.to_f.clamp(0, 100)

    if percent < 50
      # Red to Yellow: interpolate from #f44 (red) to #fa0 (yellow/orange)
      # At 0%: red, at 50%: yellow
      ratio = percent / 50.0
      r = 255
      g = (68 + (170 - 68) * ratio).round  # 68 -> 170
      b = (68 - 68 * ratio).round           # 68 -> 0
    else
      # Yellow to Green: interpolate from #fa0 (yellow) to #4f8 (green)
      # At 50%: yellow, at 100%: green
      ratio = (percent - 50) / 50.0
      r = (255 - (255 - 68) * ratio).round  # 255 -> 68
      g = (170 + (255 - 170) * ratio).round # 170 -> 255
      b = (0 + (136 - 0) * ratio).round     # 0 -> 136
    end

    format("#%02x%02x%02x", r, g, b)
  end
end
