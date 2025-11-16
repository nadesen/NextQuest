class Admin::TopicsController < ApplicationController
  before_action :authenticate_admin!
end
