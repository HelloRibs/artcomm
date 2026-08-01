require "rails_helper"

RSpec.describe User do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it "uses a uuid primary key" do
    expect(create(:user).id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it "rejects malformed emails" do
      expect(build(:user, email: "not-an-email")).not_to be_valid
    end

    it "rejects passwords shorter than 8 characters" do
      user = build(:user, password: "short")

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "requires a password on creation" do
      expect(build(:user, password: nil)).not_to be_valid
    end

    it "allows updating a record without resupplying the password" do
      user = create(:user)

      expect(user.update(email: "new@example.com")).to be(true)
    end
  end

  describe "email normalization" do
    it "downcases and strips the email" do
      user = create(:user, email: "  Artist@Example.COM ")

      expect(user.email).to eq("artist@example.com")
    end
  end

  describe "password storage" do
    it "stores a bcrypt digest rather than the raw password" do
      user = create(:user, password: "a very good password")

      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to include("a very good password")
      expect(user.authenticate("a very good password")).to eq(user)
      expect(user.authenticate("wrong password")).to be(false)
    end
  end

  describe "username" do
    it { is_expected.to validate_presence_of(:username) }

    it "downcases and strips the username" do
      expect(create(:user, username: "  PicassoJr  ").username).to eq("picassojr")
    end

    it "rejects usernames that collide with application routes" do
      User::RESERVED_USERNAMES.each do |reserved|
        user = build(:user, username: reserved)

        expect(user).not_to be_valid, "expected #{reserved.inspect} to be reserved"
        expect(user.errors[:username]).to include("is reserved")
      end
    end

    # Public pages live at /:username, so any top-level path the router already
    # claims would shadow an artist's page. This derives the list from the router
    # rather than restating it, so adding a route later fails here instead of
    # silently breaking whoever registered that name.
    it "reserves every top-level route segment that could be claimed as a username" do
      claimable = Rails.application.routes.routes.filter_map { |route|
        path = route.path.spec.to_s
        next if path.start_with?("/:")

        segment = path[%r{\A/([^/(:]+)}, 1]
        segment if segment&.match?(User::USERNAME_FORMAT)
      }.uniq

      expect(claimable - User::RESERVED_USERNAMES).to be_empty,
        "these routes are claimable as usernames: #{(claimable - User::RESERVED_USERNAMES).inspect}"
    end

    it "rejects characters that aren't URL-safe" do
      [ "has space", "has_underscore", "has.dot", "Ünicode", "-leading", "trailing-" ].each do |bad|
        expect(build(:user, username: bad)).not_to be_valid, "expected #{bad.inspect} to be rejected"
      end
    end

    it "accepts lowercase letters, digits, and interior hyphens" do
      [ "abc", "a1b2", "my-gallery-name", "123" ].each do |good|
        expect(build(:user, username: good)).to be_valid, "expected #{good.inspect} to be accepted"
      end
    end

    it "enforces a length range" do
      expect(build(:user, username: "ab")).not_to be_valid
      expect(build(:user, username: "a" * 31)).not_to be_valid
    end

    it "rejects a duplicate username regardless of casing" do
      create(:user, username: "taken")

      expect(build(:user, username: "TAKEN")).not_to be_valid
    end
  end

  describe "profile" do
    it "shows the display name publicly when set" do
      user = build(:user, username: "picasso", display_name: "Pablo Picasso")

      expect(user.public_name).to eq("Pablo Picasso")
    end

    it "falls back to the username when the display name is blank" do
      expect(build(:user, username: "picasso", display_name: " ").public_name).to eq("picasso")
    end

    it "strips everything but digits from the whatsapp number" do
      user = create(:user, whatsapp_phone: "+52 (155) 1234-5678")

      expect(user.whatsapp_phone).to eq("5215512345678")
      expect(user).to be_whatsapp
    end

    it "treats a blank whatsapp number as absent rather than invalid" do
      user = create(:user, whatsapp_phone: "")

      expect(user.whatsapp_phone).to be_nil
      expect(user).not_to be_whatsapp
    end

    it "rejects a whatsapp number with too few digits to dial" do
      expect(build(:user, whatsapp_phone: "12345")).not_to be_valid
    end
  end

  describe ".authenticate_by_credentials" do
    let!(:user) { create(:user, email: "artist@example.com", password: "a very good password") }

    it "returns the user for valid credentials" do
      result = described_class.authenticate_by_credentials(
        email: "artist@example.com", password: "a very good password"
      )

      expect(result).to eq(user)
    end

    it "matches the email case-insensitively and ignores surrounding whitespace" do
      result = described_class.authenticate_by_credentials(
        email: " Artist@Example.com ", password: "a very good password"
      )

      expect(result).to eq(user)
    end

    it "returns nil for a wrong password" do
      result = described_class.authenticate_by_credentials(
        email: "artist@example.com", password: "nope"
      )

      expect(result).to be_nil
    end

    it "returns nil for an unknown email" do
      result = described_class.authenticate_by_credentials(
        email: "nobody@example.com", password: "a very good password"
      )

      expect(result).to be_nil
    end

    it "returns nil when credentials are blank" do
      expect(described_class.authenticate_by_credentials(email: nil, password: nil)).to be_nil
    end
  end
end
