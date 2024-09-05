# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      class LocationBuilder
        class << self
          extend T::Sig

          sig { params(location_string: String).returns(Interface::Location) }
          def line_location_from_s(location_string)
            *file_parts, line = location_string.split(":")
            raise ArgumentError, "Invalid location string given" if file_parts.empty?

            # On Windows, file paths will look something like `C:/path/to/file.rb:123`. Only the last colon is the line
            # number and all other parts compose the file path
            file_path = file_parts.join(":")
            line_as_number = line ? Integer(line.to_i) - 1 : 0

            Interface::Location.new(
              uri: URI::Generic.from_path(path: file_path).to_s,
              range: Interface::Range.new(
                start: Interface::Position.new(line: line_as_number, character: 0),
                end: Interface::Position.new(line: line_as_number, character: 0),
              ),
            )
          end
        end
      end
    end
  end
end
