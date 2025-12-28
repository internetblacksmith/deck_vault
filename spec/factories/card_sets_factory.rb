FactoryBot.define do
  factory :card_set do
    sequence(:code) { |n| "SET#{n}" }
    sequence(:name) { |n| "Test Set #{n}" }
    card_count { 100 }
    download_status { "completed" }
    images_downloaded { 100 }
    released_at { Date.current }
    scryfall_uri { "https://scryfall.com/sets/test" }
  end
end
