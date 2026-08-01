FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "correct horse battery staple" }
  end
end
