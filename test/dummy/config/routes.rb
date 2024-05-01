# frozen_string_literal: true

Rails.application.routes.draw do
  resources :users do
    get :archive, on: :collection
  end
end
