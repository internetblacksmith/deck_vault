require 'rails_helper'

RSpec.describe CardSetsHelper, type: :helper do
  describe '#sortable_collector_number' do
    it 'pads simple numbers with zeros' do
      expect(helper.sortable_collector_number("1")).to eq("000001")
      expect(helper.sortable_collector_number("42")).to eq("000042")
      expect(helper.sortable_collector_number("286")).to eq("000286")
    end

    it 'handles numbers with letter suffixes' do
      expect(helper.sortable_collector_number("297a")).to eq("000297a")
      expect(helper.sortable_collector_number("297b")).to eq("000297b")
    end

    it 'handles numbers with special character suffixes' do
      expect(helper.sortable_collector_number("363★")).to eq("000363★")
    end

    it 'sorts correctly when compared' do
      numbers = [ "10", "1", "2", "297a", "297b", "100" ]
      sorted = numbers.map { |n| helper.sortable_collector_number(n) }.sort
      expect(sorted).to eq([
        "000001",
        "000002",
        "000010",
        "000100",
        "000297a",
        "000297b"
      ])
    end

    it 'returns 999999 for blank values' do
      expect(helper.sortable_collector_number(nil)).to eq("999999")
      expect(helper.sortable_collector_number("")).to eq("999999")
    end
  end

  describe '#color_sort_value' do
    it 'returns correct value for mono-colored cards' do
      expect(helper.color_sort_value("{W}")).to eq("1-White")
      expect(helper.color_sort_value("{U}")).to eq("2-Blue")
      expect(helper.color_sort_value("{B}")).to eq("3-Black")
      expect(helper.color_sort_value("{R}")).to eq("4-Red")
      expect(helper.color_sort_value("{G}")).to eq("5-Green")
    end

    it 'returns colorless for cards without WUBRG' do
      expect(helper.color_sort_value("{3}")).to eq("6-Colorless")
      expect(helper.color_sort_value("{C}")).to eq("6-Colorless")
      expect(helper.color_sort_value(nil)).to eq("6-Colorless")
    end

    it 'returns multi for multicolored cards' do
      expect(helper.color_sort_value("{W}{U}")).to eq("7-Multi")
      expect(helper.color_sort_value("{B}{R}{G}")).to eq("7-Multi")
    end

    it 'handles complex mana costs' do
      expect(helper.color_sort_value("{2}{W}{W}")).to eq("1-White")
      expect(helper.color_sort_value("{1}{U}{B}")).to eq("7-Multi")
    end
  end

  describe '#mana_value' do
    it 'calculates mana value for simple costs' do
      expect(helper.mana_value("{W}")).to eq(1)
      expect(helper.mana_value("{3}")).to eq(3)
      expect(helper.mana_value("{2}{W}{W}")).to eq(4)
    end

    it 'treats X as 0' do
      expect(helper.mana_value("{X}{R}")).to eq(1)
      expect(helper.mana_value("{X}{X}{G}")).to eq(1)
    end

    it 'handles nil mana cost' do
      expect(helper.mana_value(nil)).to eq(0)
    end

    it 'handles hybrid mana' do
      expect(helper.mana_value("{W/U}")).to eq(1)
      expect(helper.mana_value("{2}{W/B}")).to eq(3)
    end
  end

  describe '#rarity_sort_value' do
    it 'returns correct values for each rarity' do
      expect(helper.rarity_sort_value("common")).to eq(1)
      expect(helper.rarity_sort_value("uncommon")).to eq(2)
      expect(helper.rarity_sort_value("rare")).to eq(3)
      expect(helper.rarity_sort_value("mythic")).to eq(4)
    end

    it 'returns 0 for unknown rarity' do
      expect(helper.rarity_sort_value(nil)).to eq(0)
      expect(helper.rarity_sort_value("special")).to eq(0)
    end
  end
end
