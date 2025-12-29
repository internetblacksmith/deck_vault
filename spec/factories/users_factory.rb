FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    password { "SecurePassword123!" }
    password_confirmation { "SecurePassword123!" }
  end
end
