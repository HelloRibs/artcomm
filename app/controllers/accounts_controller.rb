class AccountsController < ApplicationController
  before_action :require_authentication

  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      redirect_to account_path, notice: "Profile updated."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    # Email, username, and password are deliberately not editable here — each
    # needs its own confirmation flow before it can be changed safely.
    def profile_params
      params.require(:user).permit(:display_name, :bio, :whatsapp_phone)
    end
end
