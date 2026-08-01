FactoryBot.define do
  factory :art_piece do
    project
    sequence(:title) { |n| "Piece #{n}" }
    description { Faker::Lorem.sentence }
    # position is derived by the model when left blank.

    after(:build) do |art_piece|
      unless art_piece.image.attached?
        art_piece.image.attach(
          io: Rails.root.join("spec/fixtures/files/piece.png").open,
          filename: "piece.png",
          content_type: "image/png"
        )
      end
    end

    trait :priced do
      price_amount { 1200 }
      price_currency_symbol { "$" }
      price_currency_name { "MXN" }
    end
  end
end
