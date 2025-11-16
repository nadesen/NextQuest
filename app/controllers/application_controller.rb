class ApplicationController < ActionController::Base
  before_action :authenticate_user!, except: [:top], unless: :skip_user_authentication?
  before_action :configure_permitted_parameters, if: :devise_controller?

  # ログイン中ユーザーが 停止中(suspended) なら強制ログアウトしてサインイン画面へ
  before_action :sign_out_suspended_user

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :nickname])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :nickname])
  end

  private

  def sign_out_suspended_user
    return unless user_signed_in?
    return unless current_user.suspended?

    # sign_out してフラッシュを出し、サインインページへ
    sign_out(current_user)
    redirect_to new_user_session_path, alert: 'アカウントは停止されています。管理者にお問い合わせください。'
  end

  def skip_user_authentication?
    devise_controller? || controller_path.start_with?('admin/')
  end

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
