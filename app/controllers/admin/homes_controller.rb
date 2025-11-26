class Admin::HomesController < ApplicationController
  before_action :redirect_non_admin_to_public_root
  
  def top
  end

  private

  def redirect_non_admin_to_public_root
    unless current_admin
      redirect_to root_path and return
    end
  end
  
end
