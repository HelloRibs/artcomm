require "rails_helper"

RSpec.describe "Home" do
  describe "GET /" do
    it "renders for anonymous visitors" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "shows the signed-in user's email" do
      user = create(:user)
      sign_in_as user

      get root_path

      expect(response.body).to include(user.email)
    end
  end
end
