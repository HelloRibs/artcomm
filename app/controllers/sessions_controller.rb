class SessionsController < ApplicationController
  def new
    redirect_to root_path if signed_in?
  end

  def create
    user = User.authenticate_by_credentials(
      email: params[:email],
      password: params[:password]
    )

    if user
      sign_in(user)
      redirect_to_stored_location default: root_path
    else
      @email = params[:email]
      flash.now[:alert] = "Incorrect email or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Signed out."
  end
end
