FactoryBot.define do
  factory :card_set do
    sequence(:code) { |n| "SET#{n}" }
    sequence(:name) { |n| "Test Set #{n}" }
    card_count { 100 }
    download_status { "completed" }
    images_downloaded { 100 }
    released_at { Date.current }
    scryfall_uri { "https://scryfall.com/sets/test" }
    set_type { "expansion" }
    parent_set_code { nil }
    binder_rows { 3 }
    binder_columns { 3 }
    binder_sort_field { "number" }
    binder_sort_direction { "asc" }

    trait :with_parent do
      parent_set_code { "PARENT" }
    end

    trait :core_set do
      set_type { "core" }
    end

    trait :commander do
      set_type { "commander" }
    end

    trait :promo do
      set_type { "promo" }
    end
  end
end
