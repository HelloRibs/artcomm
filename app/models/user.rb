class User < ApplicationRecord
  has_secure_password

  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, format: { with: EMAIL_FORMAT }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  # Looks up a user by email and verifies their password. Returns nil for both
  # an unknown email and a wrong password so callers can't distinguish the two.
  def self.authenticate_by_credentials(email:, password:)
    authenticate_by(email: email.to_s.strip.downcase, password: password.to_s)
  end
end
