require "rails_helper"

RSpec.describe "Accounts" do
  describe "GET /account" do
    it "redirects anonymous visitors to the login page" do
      get account_path

      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to be_present
    end

    it "renders for a signed-in user" do
      user = create(:user)
      sign_in_as user

      get account_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email)
    end
  end
end
