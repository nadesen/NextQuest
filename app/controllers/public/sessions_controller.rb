# frozen_string_literal: true

class Public::SessionsController < Devise::SessionsController
  # サインイン時に email/password の存在チェックを行う（任意）
  before_action :ensure_login_params_present, only: :create

  def after_sign_in_path_for(resource)
    if resource.respond_to?(:guest_user?) && resource.guest_user?
      forums_path # ゲストはマイページ不可
    else
      flash[:notice] = "ログインしました"
      user_path(resource) rescue root_path
    end
  end
  
  def guest_sign_in
    user = User.guest
    sign_in user
    redirect_to root_path, notice: "ゲストでログインしました。"
  end

  private

  def ensure_login_params_present
    user_params = params[resource_name] || {}
    if user_params[:email].blank? || user_params[:password].blank?
      flash[:alert] = "メールアドレスとパスワードを入力してください。"
      redirect_to new_session_path(resource_name)
    end
  end

  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
