FactoryBot.define do
  factory :card do
    card_set
    sequence(:name) { |n| "Test Card #{n}" }
    collector_number { "1" }
    type_line { "Creature — Human Wizard" }
    mana_cost { "{1}{U}" }
    rarity { "common" }
    oracle_text { "Flying\nThis creature has flying." }
    image_uris { { normal: "https://example.com/card.jpg", small: "https://example.com/card-small.jpg" }.to_json }
    image_path { nil }
    back_image_uris { nil }
    back_image_path { nil }
    foil { true }
    nonfoil { true }

    # Use initialize_with to set custom string primary key (scryfall_id)
    initialize_with do
      new(id: generate(:card_scryfall_id), **attributes.except(:id))
    end

    trait :with_image do
      after(:build) do |card|
        card.image_path = "/storage/cards/#{card.id}.jpg"
      end
    end

    trait :without_image_uris do
      image_uris { "{}" }
    end

    trait :with_collection_card do
      after(:create) do |card|
        create(:collection_card, card: card)
      end
    end

    trait :double_faced do
      sequence(:name) { |n| "DFC Front #{n} // DFC Back #{n}" }
      back_image_uris { { normal: "https://example.com/card-back.jpg", small: "https://example.com/card-back-small.jpg" }.to_json }
    end

    trait :with_back_image do
      back_image_path { "card_images/back.jpg" }
      back_image_uris { { normal: "https://example.com/card-back.jpg" }.to_json }
    end

    trait :foil_only do
      foil { true }
      nonfoil { false }
    end

    trait :nonfoil_only do
      foil { false }
      nonfoil { true }
    end
  end

  # Separate sequence for scryfall_id
  sequence(:card_scryfall_id) { |n| "00000000-0000-0000-0000-#{format('%012d', n)}" }
end
