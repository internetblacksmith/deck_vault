FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "SecurePassword123!" }
    password_confirmation { "SecurePassword123!" }
  end
end
