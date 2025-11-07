class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  # 新規登録後遷移先
  def after_sign_up_path_for(resource)
    root_path
  end

  # ログイン後遷移先
  def after_sign_in_path_for(resource)
    root_path
  end

  # ログアウト後遷移先
  def after_sign_out_path_for(resource)
    root_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :nickname])
  end
end
