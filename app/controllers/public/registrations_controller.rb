# frozen_string_literal: true

class Public::RegistrationsController < Devise::RegistrationsController
  before_action :ensure_sign_up_params_present, only: :create

  def after_sign_up_path_for(resource)
    flash[:notice] = "会員登録が完了しました"
    root_path
  end

  private

  def ensure_sign_up_params_present
    user_params = params[resource_name] || {}
    if user_params[:name].blank? || user_params[:nickname].blank? || user_params[:email].blank? || user_params[:password].blank?
      flash[:alert] = "氏名・ニックネーム・メールアドレス・パスワードは必須です。"
      redirect_to new_registration_path(resource_name)
    end
  end


  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
