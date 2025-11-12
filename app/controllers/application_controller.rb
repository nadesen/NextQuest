class ApplicationController < ActionController::Base
  before_action :authenticate_user!, except: [:top]
  before_action :configure_permitted_parameters, if: :devise_controller?

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :nickname])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :nickname])
  end

  private

  # 汎用のログイン必須フィルタ（必要なコントローラで before_action :require_login を使う）
  def require_login
    return if user_signed_in?

    store_location_for_redirect
    if request.format == Mime[:turbo_stream]
      redirect_to new_user_session_path, status: :see_other, alert: 'ログインしてください。'
    else
      redirect_to new_user_session_path, alert: 'ログインしてください。'
    end
  end

  # GET のときだけ元の URL を保存（ログイン後に戻すため）
  def store_location_for_redirect
    return unless request.get? && !request.xhr?
    # ログイン画面や登録画面自体は保存しない
    return if devise_controller? && controller_name.in?(%w[sessions registrations passwords])

    if respond_to?(:store_location_for)
      store_location_for(:user, request.fullpath)
    else
      session[:user_return_to] = request.fullpath
    end
  end

  # Devise のサインイン後に保存先へ戻す
  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || session.delete(:user_return_to) || super
  end
end
