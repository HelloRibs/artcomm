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
