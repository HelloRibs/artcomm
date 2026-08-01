require "rails_helper"

RSpec.describe Project do
  it "has a valid factory" do
    expect(build(:project)).to be_valid
  end

  it "uses a uuid primary key" do
    expect(create(:project).id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  describe "validations" do
    subject { build(:project) }

    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:title) }

    it "rejects a title longer than 120 characters" do
      expect(build(:project, title: "a" * 121)).not_to be_valid
    end

    it "rejects a slug with unsupported characters" do
      expect(build(:project, slug: "Not A Slug!")).not_to be_valid
    end
  end

  describe "slug generation" do
    let(:user) { create(:user) }

    it "derives the slug from the title" do
      project = create(:project, user: user, title: "Blue Period Sketches")

      expect(project.slug).to eq("blue-period-sketches")
    end

    it "keeps the slug unique within one artist by suffixing" do
      first = create(:project, user: user, title: "Landscapes")
      second = create(:project, user: user, title: "Landscapes")
      third = create(:project, user: user, title: "Landscapes")

      expect([ first.slug, second.slug, third.slug ]).to eq(%w[landscapes landscapes-2 landscapes-3])
    end

    it "lets two artists use the same slug" do
      other_user = create(:user)
      mine = create(:project, user: user, title: "Portraits")
      theirs = create(:project, user: other_user, title: "Portraits")

      expect(mine.slug).to eq("portraits")
      expect(theirs.slug).to eq("portraits")
    end

    it "falls back to a default when the title has no slug-able characters" do
      project = create(:project, user: user, title: "!!!")

      expect(project.slug).to eq("gallery")
    end

    it "honours an explicitly provided slug" do
      project = create(:project, user: user, title: "Anything", slug: "custom-slug")

      expect(project.slug).to eq("custom-slug")
    end

    it "keeps the slug stable when the title changes, so public URLs don't rot" do
      project = create(:project, user: user, title: "Original Title")

      project.update!(title: "A Completely New Title")

      expect(project.reload.slug).to eq("original-title")
    end

    it "rejects a duplicate slug within the same artist" do
      create(:project, user: user, slug: "taken", title: "One")
      duplicate = build(:project, user: user, slug: "taken", title: "Two")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to be_present
    end

    it "uses the slug as the URL parameter" do
      project = create(:project, user: user, title: "My Gallery")

      expect(project.to_param).to eq("my-gallery")
    end
  end

  describe "position" do
    let(:user) { create(:user) }

    it "appends new projects to the end of the artist's list" do
      first = create(:project, user: user)
      second = create(:project, user: user)

      expect([ first.position, second.position ]).to eq([ 1, 2 ])
    end

    it "counts positions per artist rather than globally" do
      create(:project, user: user)
      other_first = create(:project, user: create(:user))

      expect(other_first.position).to eq(1)
    end

    it "honours an explicitly provided position" do
      expect(create(:project, user: user, position: 7).position).to eq(7)
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    it "orders by position" do
      third = create(:project, user: user, position: 3, title: "C")
      first = create(:project, user: user, position: 1, title: "A")
      second = create(:project, user: user, position: 2, title: "B")

      expect(described_class.ordered).to eq([ first, second, third ])
    end

    it "filters to published projects" do
      published = create(:project, :published, user: user)
      create(:project, user: user)

      expect(described_class.published).to eq([ published ])
    end

    it "defaults to unpublished" do
      expect(create(:project, user: user)).not_to be_published
    end
  end

  describe "ownership" do
    it "is removed along with its owner" do
      user = create(:user)
      create(:project, user: user)

      expect { user.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
