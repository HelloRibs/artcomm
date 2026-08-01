FactoryBot.define do
  factory :project do
    user
    sequence(:title) { |n| "Gallery #{n}" }
    description { Faker::Lorem.paragraph }
    published { false }
    # slug and position are derived by the model when left blank.

    trait :published do
      published { true }
    end
  end
end
