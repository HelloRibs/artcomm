require "rails_helper"

RSpec.describe "Dashboard::ArtPieces" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project, user: user) }

  def image_upload(name = "piece.png", type = "image/png")
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files", name), type)
  end

  describe "authentication" do
    it "sends anonymous visitors to the login page" do
      piece = create(:art_piece, project: project)

      get new_dashboard_project_art_piece_path(project)
      expect(response).to redirect_to(login_path)

      post dashboard_project_art_pieces_path(project), params: { art_piece: { title: "x" } }
      expect(response).to redirect_to(login_path)

      delete dashboard_project_art_piece_path(project, piece)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "POST create" do
    before { sign_in_as user }

    it "adds a piece with an image" do
      expect do
        post dashboard_project_art_pieces_path(project),
          params: { art_piece: { title: "Sunrise", image: image_upload } }
      end.to change(project.art_pieces, :count).by(1)

      piece = project.art_pieces.last
      expect(piece.title).to eq("Sunrise")
      expect(piece.image).to be_attached
      expect(response).to redirect_to(dashboard_project_path(project))
    end

    it "stores an optional price" do
      post dashboard_project_art_pieces_path(project), params: {
        art_piece: {
          title: "Sunrise", image: image_upload,
          price_amount: "1200", price_currency_symbol: "$", price_currency_name: "MXN"
        }
      }

      expect(project.art_pieces.last.formatted_price).to eq("$1,200 MXN")
    end

    it "allows a piece with no price at all" do
      post dashboard_project_art_pieces_path(project),
        params: { art_piece: { title: "Not for sale", image: image_upload } }

      expect(project.art_pieces.last).not_to be_priced
    end

    it "rejects a piece with no image" do
      expect do
        post dashboard_project_art_pieces_path(project), params: { art_piece: { title: "Missing" } }
      end.not_to change(ArtPiece, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a file that isn't an image" do
      expect do
        post dashboard_project_art_pieces_path(project), params: {
          art_piece: { title: "Bad", image: image_upload("not_an_image.txt", "text/plain") }
        }
      end.not_to change(ArtPiece, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Re-rendering the form used to raise while thumbnailing an attachment that
    # was never saved, turning a validation error into a 500.
    it "re-renders the form with an error when a valid image has no title" do
      post dashboard_project_art_pieces_path(project),
        params: { art_piece: { title: "", image: image_upload } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Title can&#39;t be blank")
    end

    it "re-renders the form with an error when the upload is rejected" do
      post dashboard_project_art_pieces_path(project), params: {
        art_piece: { title: "Bad", image: image_upload("not_an_image.txt", "text/plain") }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("JPEG, PNG, WebP, or GIF")
    end

    it "re-renders the edit form with an error without losing the saved image" do
      piece = create(:art_piece, project: project)

      patch dashboard_project_art_piece_path(project, piece), params: { art_piece: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(piece.reload.image).to be_attached
    end

    it "refuses to add a piece to another artist's gallery" do
      theirs = create(:project, user: other_user)

      expect do
        post dashboard_project_art_pieces_path(theirs),
          params: { art_piece: { title: "Sneaky", image: image_upload } }
      end.not_to change(ArtPiece, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH update" do
    before { sign_in_as user }

    it "updates the artist's own piece" do
      piece = create(:art_piece, project: project, title: "Before")

      patch dashboard_project_art_piece_path(project, piece), params: { art_piece: { title: "After" } }

      expect(piece.reload.title).to eq("After")
    end

    it "keeps the existing image when no new file is sent" do
      piece = create(:art_piece, project: project)
      original_blob_id = piece.image.blob.id

      patch dashboard_project_art_piece_path(project, piece), params: { art_piece: { title: "Renamed" } }

      expect(piece.reload.image.blob.id).to eq(original_blob_id)
    end

    it "refuses to update a piece in another artist's gallery" do
      theirs = create(:project, user: other_user)
      piece = create(:art_piece, project: theirs, title: "Untouched")

      patch dashboard_project_art_piece_path(theirs, piece), params: { art_piece: { title: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(piece.reload.title).to eq("Untouched")
    end
  end

  describe "DELETE destroy" do
    before { sign_in_as user }

    it "removes the artist's own piece" do
      piece = create(:art_piece, project: project)

      expect { delete dashboard_project_art_piece_path(project, piece) }
        .to change(project.art_pieces, :count).by(-1)
    end

    it "refuses to remove a piece from another artist's gallery" do
      theirs = create(:project, user: other_user)
      piece = create(:art_piece, project: theirs)

      expect { delete dashboard_project_art_piece_path(theirs, piece) }.not_to change(ArtPiece, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST move" do
    before { sign_in_as user }

    it "reorders pieces within the gallery" do
      first = create(:art_piece, project: project, title: "First")
      second = create(:art_piece, project: project, title: "Second")

      post move_dashboard_project_art_piece_path(project, second, direction: "up")

      expect(project.art_pieces.reload.ordered.map(&:title)).to eq(%w[Second First])
      expect(response).to redirect_to(dashboard_project_path(project))
      expect(first).to be_persisted
    end

    it "is a harmless no-op at the end of the list" do
      first = create(:art_piece, project: project, title: "First")
      create(:art_piece, project: project, title: "Second")

      post move_dashboard_project_art_piece_path(project, first, direction: "up")

      expect(response).to redirect_to(dashboard_project_path(project))
      expect(project.art_pieces.reload.ordered.map(&:title)).to eq(%w[First Second])
    end

    it "refuses to reorder another artist's gallery" do
      theirs = create(:project, user: other_user)
      piece = create(:art_piece, project: theirs)

      post move_dashboard_project_art_piece_path(theirs, piece, direction: "up")

      expect(response).to have_http_status(:not_found)
    end
  end
end
