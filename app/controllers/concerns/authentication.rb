module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :signed_in?
  end

  private
    def current_user
      return @current_user if defined?(@current_user)

      @current_user = session[:user_id] && User.find_by(id: session[:user_id])
    end

    def signed_in?
      current_user.present?
    end

    def sign_in(user)
      # Guard against session fixation: a fresh session id for the new identity.
      # `reset_session` drops everything, so carry the post-login destination over.
      return_to = session[:return_to]
      reset_session
      session[:return_to] = return_to if return_to
      session[:user_id] = user.id
      @current_user = user
    end

    def sign_out
      reset_session
      @current_user = nil
    end

    def require_authentication
      return if signed_in?

      session[:return_to] = request.fullpath if request.get?
      redirect_to login_path, alert: "Please sign in to continue."
    end

    def redirect_to_stored_location(default:)
      redirect_to(session.delete(:return_to) || default)
    end
end
