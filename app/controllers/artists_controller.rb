class ArtistsController < ApplicationController
  layout "public"

  def show
    @artist = User.find_by!(username: params[:username])
    @projects = visible_projects_for(@artist)
  end

  private
    # The public sees published galleries only; the owner also sees their drafts
    # so they can preview the page before publishing.
    def visible_projects_for(artist)
      return artist.projects if current_user == artist

      artist.projects.published
    end
end
