# typed: strict
# frozen_string_literal: true

RubyLsp::Rails::Engine.routes.draw do
  resources :models, only: [:show]
end
