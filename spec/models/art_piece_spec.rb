require "rails_helper"

RSpec.describe ArtPiece do
  def upload(name, type)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files", name), type)
  end

  it "has a valid factory" do
    expect(build(:art_piece)).to be_valid
  end

  it "uses a uuid primary key" do
    expect(create(:art_piece).id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  describe "validations" do
    subject { build(:art_piece) }

    it { is_expected.to belong_to(:project) }
    it { is_expected.to validate_presence_of(:title) }

    it "requires an image" do
      piece = build(:art_piece)
      piece.image.detach

      expect(piece).not_to be_valid
      expect(piece.errors[:image]).to include("is required")
    end

    it "rejects a file that isn't a supported image" do
      piece = build(:art_piece)
      piece.image.attach(upload("not_an_image.txt", "text/plain"))

      expect(piece).not_to be_valid
      expect(piece.errors[:image].join).to include("JPEG, PNG, WebP, or GIF")
    end

    it "accepts each supported image type" do
      %w[image/jpeg image/png image/webp image/gif].each do |type|
        piece = build(:art_piece)
        piece.image.attach(io: StringIO.new("bytes"), filename: "x", content_type: type)

        expect(piece).to be_valid, "expected #{type} to be accepted"
      end
    end

    it "rejects an image over the size limit" do
      piece = build(:art_piece)
      piece.image.attach(
        io: StringIO.new("x" * (described_class::MAX_IMAGE_BYTES + 1)),
        filename: "huge.png", content_type: "image/png"
      )

      expect(piece).not_to be_valid
      expect(piece.errors[:image].join).to include("smaller than")
    end
  end

  describe "pricing" do
    it "is optional — this is a portfolio, not a store" do
      piece = create(:art_piece)

      expect(piece).not_to be_priced
      expect(piece.formatted_price).to be_nil
    end

    it "formats symbol, amount, and currency name together" do
      piece = build(:art_piece, price_amount: 1200, price_currency_symbol: "$", price_currency_name: "MXN")

      expect(piece.formatted_price).to eq("$1,200 MXN")
    end

    it "degrades to a bare number when symbol and name are absent" do
      piece = build(:art_piece, price_amount: 1200)

      expect(piece.formatted_price).to eq("1,200")
    end

    it "omits the currency name when only a symbol is given" do
      piece = build(:art_piece, price_amount: 40, price_currency_symbol: "€")

      expect(piece.formatted_price).to eq("€40")
    end

    it "omits the symbol when only a name is given" do
      piece = build(:art_piece, price_amount: 40, price_currency_name: "EUR")

      expect(piece.formatted_price).to eq("40 EUR")
    end

    it "accepts a free piece priced at zero" do
      piece = build(:art_piece, price_amount: 0)

      expect(piece).to be_valid
      expect(piece).to be_priced
    end

    it "rejects a negative price" do
      expect(build(:art_piece, price_amount: -1)).not_to be_valid
    end

    it "rejects currency details with no amount, which would render as an empty price" do
      piece = build(:art_piece, price_currency_symbol: "$", price_currency_name: "MXN")

      expect(piece).not_to be_valid
      expect(piece.errors[:price_amount].join).to include("required when a currency is given")
    end
  end

  describe "image variants" do
    # The fixture is deliberately larger than both variant limits, so these
    # assert real downscaling rather than passing because nothing had to change.
    let(:piece) do
      piece = build(:art_piece)
      piece.image.attach(upload("large_piece.png", "image/png"))
      piece.save!
      piece
    end

    def dimensions_of(variant)
      image = Vips::Image.new_from_buffer(piece.image.variant(variant).processed.download, "")
      [ image.width, image.height ]
    end

    it "scales the thumbnail down to its bounds" do
      expect(dimensions_of(:thumb)).to eq([ 600, 450 ])
    end

    it "scales the display variant down to its bounds" do
      expect(dimensions_of(:display)).to eq([ 1600, 1200 ])
    end

    it "preserves the aspect ratio" do
      width, height = dimensions_of(:thumb)

      expect(width.to_f / height).to be_within(0.01).of(2000.0 / 1500)
    end

    it "leaves an image already inside the bounds alone" do
      small = create(:art_piece)

      image = Vips::Image.new_from_buffer(small.image.variant(:thumb).processed.download, "")

      expect([ image.width, image.height ]).to eq([ 400, 300 ])
    end
  end

  describe "position" do
    let(:project) { create(:project) }

    it "appends new pieces to the end of the gallery" do
      first = create(:art_piece, project: project)
      second = create(:art_piece, project: project)

      expect([ first.position, second.position ]).to eq([ 1, 2 ])
    end

    it "counts positions per gallery rather than globally" do
      create(:art_piece, project: project)
      elsewhere = create(:art_piece, project: create(:project))

      expect(elsewhere.position).to eq(1)
    end

    it "orders by position" do
      second = create(:art_piece, project: project, position: 2)
      first = create(:art_piece, project: project, position: 1)

      expect(project.art_pieces.ordered).to eq([ first, second ])
    end
  end

  describe "ownership" do
    it "reaches the artist through its gallery" do
      artist = create(:user)
      piece = create(:art_piece, project: create(:project, user: artist))

      expect(piece.user).to eq(artist)
    end

    it "is removed along with its gallery" do
      project = create(:project)
      create(:art_piece, project: project)

      expect { project.destroy! }.to change(described_class, :count).by(-1)
    end

    it "is removed along with the artist" do
      artist = create(:user)
      create(:art_piece, project: create(:project, user: artist))

      expect { artist.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
