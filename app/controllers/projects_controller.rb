class ProjectsController < ApplicationController
  layout "public"

  def show
    @artist = User.find_by!(username: params[:username])
    @project = @artist.projects.find_by!(slug: params[:id])

    # An unpublished gallery reads as missing to everyone but its owner, so a
    # draft URL can't be probed for.
    raise ActiveRecord::RecordNotFound unless @project.published? || owner?
  end

  private
    def owner?
      current_user == @artist
    end
    helper_method :owner?
end
