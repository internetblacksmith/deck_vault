FactoryBot.define do
  factory :collection_card do
    association :card, factory: :card
    quantity { 1 }
    foil_quantity { 0 }
    page_number { 1 }
    notes { nil }

    trait :multiple_copies do
      quantity { 4 }
    end

    trait :with_foils do
      foil_quantity { 2 }
    end

    trait :foil_only do
      quantity { 0 }
      foil_quantity { 1 }
    end

    trait :without_quantity do
      quantity { nil }
    end

    trait :without_page do
      page_number { nil }
    end

    trait :with_notes do
      notes { "Foil copy, slight edge wear" }
    end

    trait :back_page do
      page_number { 200 }
    end
  end
end
