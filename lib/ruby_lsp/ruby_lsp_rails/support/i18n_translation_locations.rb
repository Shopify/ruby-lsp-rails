# typed: strict
# frozen_string_literal: true

require "psych"

module RubyLsp
  module Rails
    module Support
      # Finds source locations for translations in files loaded by I18n's simple backend.
      class I18nTranslationLocations
        #: -> void
        def initialize
          @file_cache = {} #: Hash[String, [Time, Time, Integer, Hash[[String, Array[String]], Array[Integer]]]]
        end

        #: (String key, load_path: Array[String], available_locales: Array[String | Symbol], separator: String?) -> Array[String]
        def locations(key, load_path:, available_locales:, separator:)
          return [] if key.empty?

          locales = available_locales.map(&:to_s).sort
          key_parts = separator ? key.split(separator, -1) : [key]
          return [] if key_parts.empty? || key_parts.any?(&:empty?)

          paths = load_path.filter_map do |path|
            next unless [".yml", ".yaml"].include?(File.extname(path).downcase)

            File.expand_path(path)
          end

          @file_cache.delete_if { |path, _cache| !paths.include?(path) }

          paths.flat_map do |path|
            index = index_for(path)
            locales.flat_map do |locale|
              index.fetch([locale, key_parts], []).map { |line| "#{path}:#{line}" }
            end
          end.uniq
        end

        private

        #: (String path) -> Hash[[String, Array[String]], Array[Integer]]
        def index_for(path)
          stat = File.stat(path)
          cache = @file_cache[path]

          unless cache && cache[0] == stat.mtime && cache[1] == stat.ctime && cache[2] == stat.size
            index = find_locations(path)
            cache = [stat.mtime, stat.ctime, stat.size, index]
            @file_cache[path] = cache
          end

          cache[3]
        rescue Psych::Exception, SystemCallError, EncodingError
          {}
        end

        #: (String path) -> Hash[[String, Array[String]], Array[Integer]]
        def find_locations(path)
          index = Hash.new { |hash, key| hash[key] = [] } #: Hash[[String, Array[String]], Array[Integer]]
          stream = Psych.parse_stream(File.read(path))

          stream.children.each do |document|
            root = document.root
            next unless root.is_a?(Psych::Nodes::Mapping)

            root.children.each_slice(2) do |locale_node, translations_node|
              next unless locale_node.is_a?(Psych::Nodes::Scalar)

              index_translations(translations_node, locale_node.value, [], index)
            end
          end

          index
        end

        #: (Psych::Nodes::Node? node, String locale, Array[String] key_parts, Hash[[String, Array[String]], Array[Integer]] index) -> void
        def index_translations(node, locale, key_parts, index)
          return unless node.is_a?(Psych::Nodes::Mapping)

          node.children.each_slice(2) do |key_node, value_node|
            next unless key_node.is_a?(Psych::Nodes::Scalar)

            path = [*key_parts, key_node.value]
            locations = index[[locale, path]] ||= []
            locations << key_node.start_line + 1
            index_translations(value_node, locale, path, index)
          end
        end
      end
    end
  end
end
