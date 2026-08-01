require "rails_helper"

RSpec.describe Reordering do
  let(:project) { create(:project) }
  let!(:first)  { create(:art_piece, project: project, title: "First") }
  let!(:second) { create(:art_piece, project: project, title: "Second") }
  let!(:third)  { create(:art_piece, project: project, title: "Third") }

  def titles
    project.art_pieces.reload.ordered.map(&:title)
  end

  it "moves a record up one place" do
    described_class.new(project.art_pieces).move(second, direction: "up")

    expect(titles).to eq(%w[Second First Third])
  end

  it "moves a record down one place" do
    described_class.new(project.art_pieces).move(second, direction: "down")

    expect(titles).to eq(%w[First Third Second])
  end

  it "returns true when a record actually moved" do
    result = described_class.new(project.art_pieces).move(second, direction: "up")

    expect(result).to be(true)
  end

  it "leaves the first record alone when moved up" do
    result = described_class.new(project.art_pieces).move(first, direction: "up")

    expect(result).to be(false)
    expect(titles).to eq(%w[First Second Third])
  end

  it "leaves the last record alone when moved down" do
    result = described_class.new(project.art_pieces).move(third, direction: "down")

    expect(result).to be(false)
    expect(titles).to eq(%w[First Second Third])
  end

  it "ignores an unrecognised direction rather than raising" do
    result = described_class.new(project.art_pieces).move(second, direction: "sideways")

    expect(result).to be(false)
    expect(titles).to eq(%w[First Second Third])
  end

  it "ignores a nil direction" do
    expect(described_class.new(project.art_pieces).move(second, direction: nil)).to be(false)
  end

  # Ties are expected: the column defaults to 0, so anything created before
  # positions were assigned — or imported — can collide.
  it "still reorders when every position is tied" do
    ArtPiece.where(project: project).update_all(position: 0)

    described_class.new(project.art_pieces).move(third, direction: "up")

    expect(titles).to eq(%w[First Third Second])
  end

  it "closes gaps left by a deleted record" do
    second.destroy!

    described_class.new(project.art_pieces).move(third, direction: "up")

    expect(titles).to eq(%w[Third First])
    expect(project.art_pieces.reload.ordered.map(&:position)).to eq([ 1, 2 ])
  end

  it "does not touch another gallery's ordering" do
    other_project = create(:project)
    other_first = create(:art_piece, project: other_project, title: "Other First")
    other_second = create(:art_piece, project: other_project, title: "Other Second")

    described_class.new(project.art_pieces).move(second, direction: "up")

    expect(other_project.art_pieces.reload.ordered).to eq([ other_first, other_second ])
  end

  it "works for galleries as well as pieces" do
    artist = create(:user)
    alpha = create(:project, user: artist, title: "Alpha")
    beta = create(:project, user: artist, title: "Beta")

    described_class.new(artist.projects).move(beta, direction: "up")

    expect(artist.projects.reload.ordered.map(&:title)).to eq(%w[Beta Alpha])
  end
end
