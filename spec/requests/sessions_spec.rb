require "rails_helper"

RSpec.describe "Sessions" do
  let(:password) { "a very good password" }
  let!(:user) { create(:user, email: "artist@example.com", password: password) }

  describe "GET /login" do
    it "renders the form" do
      get login_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects signed-in users to the root path" do
      post login_path, params: { email: user.email, password: password }

      get login_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /login" do
    it "signs the user in" do
      post login_path, params: { email: user.email, password: password }

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(user.id)
    end

    it "rejects a wrong password without starting a session" do
      post login_path, params: { email: user.email, password: "wrong" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:user_id]).to be_nil
    end

    it "rejects an unknown email without starting a session" do
      post login_path, params: { email: "nobody@example.com", password: password }

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:user_id]).to be_nil
    end

    it "gives the same message for a wrong password and an unknown email" do
      post login_path, params: { email: user.email, password: "wrong" }
      wrong_password_message = flash[:alert]

      post login_path, params: { email: "nobody@example.com", password: password }

      expect(flash[:alert]).to eq(wrong_password_message)
      expect(wrong_password_message).to be_present
    end

    it "returns the user to the page they were asked to sign in for" do
      get account_path
      expect(response).to redirect_to(login_path)

      post login_path, params: { email: user.email, password: password }

      expect(response).to redirect_to(account_path)
    end

    it "issues a new session id to guard against session fixation" do
      get login_path
      session_id_before = session.id

      post login_path, params: { email: user.email, password: password }

      expect(session.id).not_to eq(session_id_before)
    end
  end

  describe "DELETE /logout" do
    it "clears the session" do
      post login_path, params: { email: user.email, password: password }
      expect(session[:user_id]).to eq(user.id)

      delete logout_path

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to be_nil
    end
  end
end
