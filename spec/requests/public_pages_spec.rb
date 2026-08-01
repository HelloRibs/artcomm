require "rails_helper"

RSpec.describe "Public artist pages" do
  let(:artist) { create(:user, username: "picasso", display_name: "Pablo Picasso", bio: "Painter.") }
  let(:visitor) { create(:user) }

  describe "GET /:username" do
    it "shows the artist's published galleries" do
      published = create(:project, :published, user: artist, title: "Blue Period")

      get artist_path(artist.username)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pablo Picasso", "Painter.", published.title)
    end

    it "hides drafts from the public" do
      create(:project, user: artist, title: "Unfinished Work")

      get artist_path(artist.username)

      expect(response.body).not_to include("Unfinished Work")
    end

    it "shows the owner their own drafts so they can preview" do
      create(:project, user: artist, title: "Unfinished Work")
      sign_in_as artist

      get artist_path(artist.username)

      expect(response.body).to include("Unfinished Work")
    end

    it "does not show drafts to a different signed-in artist" do
      create(:project, user: artist, title: "Unfinished Work")
      sign_in_as visitor

      get artist_path(artist.username)

      expect(response.body).not_to include("Unfinished Work")
    end

    it "404s for an unknown username" do
      get "/nobody-here"

      expect(response).to have_http_status(:not_found)
    end

    it "falls back to the username when no display name is set" do
      plain = create(:user, username: "quiet", display_name: nil)

      get artist_path(plain.username)

      expect(response.body).to include("quiet")
    end

    it "carries no platform branding" do
      get artist_path(artist.username)

      expect(response.body).not_to match(/artcomm/i)
    end
  end

  describe "GET /:username/:slug" do
    it "shows a published gallery" do
      project = create(:project, :published, user: artist, title: "Blue Period")

      get project_path(artist.username, project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blue Period")
    end

    it "404s on a draft for the public" do
      project = create(:project, user: artist, title: "Unfinished")

      get project_path(artist.username, project)

      expect(response).to have_http_status(:not_found)
    end

    it "404s on a draft for a different signed-in artist" do
      project = create(:project, user: artist)
      sign_in_as visitor

      get project_path(artist.username, project)

      expect(response).to have_http_status(:not_found)
    end

    it "lets the owner preview their own draft" do
      project = create(:project, user: artist, title: "Unfinished")
      sign_in_as artist

      get project_path(artist.username, project)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Unfinished")
    end

    it "404s when the gallery belongs to a different artist" do
      other = create(:user, username: "matisse")
      project = create(:project, :published, user: other, title: "Not Picasso's")

      get project_path(artist.username, project.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "404s for an unknown slug" do
      get "/#{artist.username}/no-such-gallery"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "route precedence" do
    it "keeps real application paths from being swallowed by /:username" do
      { "/login" => 200, "/signup" => 200, "/up" => 200 }.each do |path, status|
        get path

        expect(response).to have_http_status(status), "expected #{path} to still resolve"
      end
    end
  end
end
