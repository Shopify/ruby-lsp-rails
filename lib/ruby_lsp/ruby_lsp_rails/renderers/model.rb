# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Renderer
      module Hover
        class Model
          attr_reader :model, :name, :type

          def initialize(type, model, name)
            @type = type
            @model = model
            @name = name
          end

          def render
            b = binding
            ERB.new(File.read("#{File.dirname(__FILE__)}/templates/#{@type}.erb")).result(b)
          end
        end
      end
    end
  end
end
