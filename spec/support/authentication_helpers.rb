module AuthenticationHelpers
  # Signs in through the real login endpoint so request specs exercise the
  # same session-setting path as a browser would.
  def sign_in_as(user, password: "correct horse battery staple")
    post login_path, params: { email: user.email, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
