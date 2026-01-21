# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      module Routes
        ALL = [
          "get",
          "post",
          "put",
          "patch",
          "delete",
          "match",
        ].freeze

        ROUTE_FILES_PATTERN = %r{(^|/)config/routes(?:/[^/]+)?\.rb$}
      end
    end
  end
end
