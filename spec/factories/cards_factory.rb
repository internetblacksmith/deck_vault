FactoryBot.define do
  factory :card do
    card_set
    sequence(:name) { |n| "Test Card #{n}" }
    sequence(:scryfall_id) { |n| "00000000-0000-0000-0000-#{format('%012d', n)}" }
    collector_number { "1" }
    type_line { "Creature — Human Wizard" }
    mana_cost { "{1}{U}" }
    rarity { "common" }
    oracle_text { "Flying\nThis creature has flying." }
    image_uris { { normal: "https://example.com/card.jpg", small: "https://example.com/card-small.jpg" }.to_json }
    image_path { nil }

    trait :with_image do
      image_path { "/storage/cards/#{scryfall_id}.jpg" }
    end

    trait :without_image_uris do
      image_uris { "{}" }
    end

    trait :with_collection_card do
      after(:create) do |card|
        create(:collection_card, card: card)
      end
    end
  end
end
