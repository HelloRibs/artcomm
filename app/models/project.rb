class Project < ApplicationRecord
  belongs_to :user

  SLUG_FORMAT = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/

  scope :ordered, -> { order(:position, :created_at) }
  scope :published, -> { where(published: true) }

  before_validation :assign_slug
  before_validation :assign_position, on: :create

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 5_000 }
  validates :slug,
    presence: true,
    length: { maximum: 120 },
    format: { with: SLUG_FORMAT, message: "may only contain lowercase letters, numbers, and hyphens" },
    uniqueness: { scope: :user_id }

  def to_param
    slug
  end

  private
    # Derive the slug from the title on create, but keep it stable afterwards so
    # published URLs don't rot when an artist renames a gallery. Setting the slug
    # explicitly still works — this only fills a blank one.
    def assign_slug
      return if slug.present?

      base = title.to_s.parameterize.presence || "gallery"
      candidate = base
      suffix = 2

      while siblings.exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      self.slug = candidate
    end

    def assign_position
      return if position.to_i.positive?

      self.position = (siblings.maximum(:position) || 0) + 1
    end

    # The owner's other projects — the scope slugs and positions are unique within.
    def siblings
      self.class.where(user_id: user_id).where.not(id: id)
    end
end
