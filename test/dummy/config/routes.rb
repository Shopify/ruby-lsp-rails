# typed: true
# frozen_string_literal: true

# The mapper doesn't draw routes in test mode without this.
ActionDispatch::Routing::Mapper.route_source_locations = true

Rails.application.routes.draw do
  resources :users, only: :index
end
