FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "correct horse battery staple" }
    sequence(:username) { |n| "artist-#{n}" }

    trait :with_profile do
      display_name { Faker::Name.name }
      bio { Faker::Lorem.paragraph }
      whatsapp_phone { "5215512345678" }
    end
  end
end
