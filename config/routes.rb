# typed: strict
# frozen_string_literal: true

RailsRubyLsp::Engine.routes.draw do
  resources :models, only: [:show]
end
