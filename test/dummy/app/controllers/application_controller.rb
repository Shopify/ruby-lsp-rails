# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def create
    user_path(1)
    user_url(1)
    users_path
    archive_users_path
    invalid_path
  end
end
