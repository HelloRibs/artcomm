module Dashboard
  class ProjectsController < ApplicationController
    before_action :require_authentication
    before_action :set_project, only: %i[show edit update destroy]

    def index
      @projects = current_user.projects
    end

    def show
    end

    def new
      @project = current_user.projects.new
    end

    def create
      @project = current_user.projects.new(project_params)

      if @project.save
        redirect_to dashboard_project_path(@project), notice: "Gallery created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @project.update(project_params)
        redirect_to dashboard_project_path(@project), notice: "Gallery updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @project.destroy!
      redirect_to dashboard_projects_path, notice: "Gallery deleted."
    end

    private
      # Scoping the lookup to current_user means someone else's slug reads as
      # missing rather than forbidden, which also avoids confirming it exists.
      def set_project
        @project = current_user.projects.find_by!(slug: params[:id])
      end

      def project_params
        params.require(:project).permit(:title, :slug, :description, :published, :position)
      end
  end
end
