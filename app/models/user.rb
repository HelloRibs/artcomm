class User < ApplicationRecord
  has_secure_password

  has_many :projects, -> { ordered }, dependent: :destroy, inverse_of: :user

  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  USERNAME_FORMAT = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/

  # Usernames sit at the root of the public URL space (/:username), so anything
  # the router already claims has to stay off limits.
  # Kept in step with the router by the spec in spec/models/user_spec.rb, which
  # fails if a new top-level route becomes claimable as a username.
  RESERVED_USERNAMES = %w[
    account accounts admin api assets cable dashboard login logout manifest
    privacy projects rails service-worker settings signup terms up users
  ].freeze

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :username, with: ->(username) { username.to_s.strip.downcase }
  normalizes :whatsapp_phone, with: ->(phone) { phone.to_s.gsub(/\D/, "").presence }

  validates :email, presence: true, format: { with: EMAIL_FORMAT }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :username,
    presence: true,
    length: { minimum: 3, maximum: 30 },
    format: { with: USERNAME_FORMAT, message: "may only contain lowercase letters, numbers, and hyphens" },
    exclusion: { in: RESERVED_USERNAMES, message: "is reserved" },
    uniqueness: true
  validates :display_name, length: { maximum: 100 }
  validates :bio, length: { maximum: 2_000 }
  # Loose on purpose: country codes and national number lengths vary too much to
  # validate precisely, and a rejected real number is worse than a bad wa.me link.
  validates :whatsapp_phone, format: { with: /\A\d{6,15}\z/, message: "must be 6-15 digits including the country code" },
    allow_nil: true

  # Looks up a user by email and verifies their password. Returns nil for both
  # an unknown email and a wrong password so callers can't distinguish the two.
  def self.authenticate_by_credentials(email:, password:)
    authenticate_by(email: email.to_s.strip.downcase, password: password.to_s)
  end

  # What the public should call this artist.
  def public_name
    display_name.presence || username
  end

  def whatsapp?
    whatsapp_phone.present?
  end
end
