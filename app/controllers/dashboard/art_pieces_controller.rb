module Dashboard
  class ArtPiecesController < ApplicationController
    before_action :require_authentication
    before_action :set_project
    before_action :set_art_piece, only: %i[edit update destroy move]

    def new
      @art_piece = @project.art_pieces.new
    end

    def create
      @art_piece = @project.art_pieces.new(art_piece_params)

      if @art_piece.save
        redirect_to dashboard_project_path(@project), notice: "Piece added."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @art_piece.update(art_piece_params)
        redirect_to dashboard_project_path(@project), notice: "Piece updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @art_piece.destroy!
      redirect_to dashboard_project_path(@project), notice: "Piece removed."
    end

    def move
      Reordering.new(@project.art_pieces).move(@art_piece, direction: params[:direction])
      redirect_to dashboard_project_path(@project)
    end

    private
      # Scoped through current_user so another artist's project is simply missing.
      def set_project
        @project = current_user.projects.find_by!(slug: params[:project_id])
      end

      def set_art_piece
        @art_piece = @project.art_pieces.find(params[:id])
      end

      def art_piece_params
        params.require(:art_piece).permit(
          :title, :description, :image,
          :price_amount, :price_currency_symbol, :price_currency_name
        )
      end
  end
end
