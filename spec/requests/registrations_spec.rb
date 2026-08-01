require "rails_helper"

RSpec.describe "Registrations" do
  describe "GET /signup" do
    it "renders the form" do
      get signup_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects signed-in users to the root path" do
      sign_in_as create(:user)

      get signup_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /signup" do
    let(:valid_params) do
      {
        user: {
          email: "artist@example.com",
          username: "newartist",
          password: "a very good password",
          password_confirmation: "a very good password"
        }
      }
    end

    it "creates the user and signs them in" do
      expect { post signup_path, params: valid_params }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(User.last.id)
    end

    it "rejects a mismatched password confirmation" do
      params = valid_params.deep_merge(user: { password_confirmation: "something else" })

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:user_id]).to be_nil
    end

    it "rejects a duplicate email regardless of casing" do
      create(:user, email: "artist@example.com")

      params = valid_params.deep_merge(user: { email: "ARTIST@example.com" })

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an invalid email" do
      params = valid_params.deep_merge(user: { email: "nope" })

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires a username" do
      params = valid_params.deep_merge(user: { username: "" })

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a username that would shadow an application route" do
      params = valid_params.deep_merge(user: { username: "login" })

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a username already taken" do
      create(:user, username: "newartist")

      expect { post signup_path, params: valid_params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
