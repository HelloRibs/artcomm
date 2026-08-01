class RegistrationsController < ApplicationController
  def new
    return redirect_to root_path if signed_in?

    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      sign_in(@user)
      redirect_to root_path, notice: "Welcome to artcomm."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.require(:user).permit(:email, :username, :password, :password_confirmation)
    end
end
