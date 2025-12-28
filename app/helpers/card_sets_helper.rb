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
end
