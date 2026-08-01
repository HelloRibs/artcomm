class ArtPiece < ApplicationRecord
  ACCEPTED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_IMAGE_BYTES = 15.megabytes

  belongs_to :project

  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 600, 600 ], preprocessed: true
    attachable.variant :display, resize_to_limit: [ 1600, 1600 ]
  end

  scope :ordered, -> { order(:position, :created_at) }

  before_validation :assign_position, on: :create

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 5_000 }
  validates :price_amount,
    numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 },
    allow_nil: true
  validates :price_currency_symbol, length: { maximum: 8 }
  validates :price_currency_name, length: { maximum: 40 }
  validate  :image_must_be_attached
  validate  :image_must_be_a_supported_size_and_type
  validate  :currency_details_require_an_amount

  delegate :user, to: :project

  def priced?
    price_amount.present?
  end

  # "$1,200 MXN". Symbol and name are both optional, so this degrades to a bare
  # number rather than rendering stray punctuation. Whole amounts lose their
  # trailing zeros, since that's how prices are normally written.
  def formatted_price
    return nil unless priced?

    amount = price_amount.round(2)
    number = ActiveSupport::NumberHelper.number_to_rounded(
      amount, precision: amount.frac.zero? ? 0 : 2, delimiter: ","
    )

    [ "#{price_currency_symbol}#{number}".strip, price_currency_name.presence ].compact.join(" ")
  end

  private
    def assign_position
      return if position.to_i.positive?

      self.position = (self.class.where(project_id: project_id).maximum(:position) || 0) + 1
    end

    def image_must_be_attached
      errors.add(:image, "is required") unless image.attached?
    end

    def image_must_be_a_supported_size_and_type
      return unless image.attached?

      unless image.content_type.in?(ACCEPTED_IMAGE_TYPES)
        errors.add(:image, "must be a JPEG, PNG, WebP, or GIF")
      end

      if image.byte_size > MAX_IMAGE_BYTES
        errors.add(:image, "must be smaller than #{MAX_IMAGE_BYTES / 1.megabyte}MB")
      end
    end

    def currency_details_require_an_amount
      return if priced?
      return if price_currency_symbol.blank? && price_currency_name.blank?

      errors.add(:price_amount, "is required when a currency is given")
    end
end
