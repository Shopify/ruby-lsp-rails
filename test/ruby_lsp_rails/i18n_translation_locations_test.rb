# typed: true
# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "ruby_lsp/ruby_lsp_rails/support/i18n_translation_locations"

module RubyLsp
  module Rails
    module Support
      class I18nTranslationLocationsTest < ActiveSupport::TestCase
        test "finds nested keys for available locales" do
          Dir.mktmpdir do |directory|
            path = File.join(directory, "translations.yml")
            File.write(path, <<~YAML)
              en:
                greeting:
                  hello: Hello
              es:
                greeting:
                  hello: Hola
              de:
                greeting:
                  hello: Hallo
            YAML

            resolver = I18nTranslationLocations.new

            assert_equal(
              ["#{path}:3"],
              resolver.locations("greeting.hello", load_path: [path], available_locales: [:en], separator: "."),
            )

            locations = resolver.locations(
              "greeting.hello",
              load_path: [path],
              available_locales: [:en, :es],
              separator: ".",
            )

            assert_equal(["#{path}:3", "#{path}:6"], locations)
          end
        end

        test "refreshes cached locations when a translation file changes" do
          Dir.mktmpdir do |directory|
            path = File.join(directory, "translations.yml")
            resolver = I18nTranslationLocations.new
            File.write(path, "en:\n  greeting: Hello\n")

            assert_equal(
              ["#{path}:2"],
              resolver.locations("greeting", load_path: [path], available_locales: [:en], separator: "."),
            )

            File.write(path, "# updated\nen:\n  greeting: Hello\n")

            assert_equal(
              ["#{path}:3"],
              resolver.locations("greeting", load_path: [path], available_locales: [:en], separator: "."),
            )
          end
        end

        test "ignores malformed and non-YAML translation sources" do
          Dir.mktmpdir do |directory|
            malformed_path = File.join(directory, "malformed.yml")
            ruby_path = File.join(directory, "translations.rb")
            File.write(malformed_path, "en:\n  greeting: [\n")
            File.write(ruby_path, "{ en: { greeting: 'Hello' } }")

            locations = I18nTranslationLocations.new.locations(
              "greeting",
              load_path: [malformed_path, ruby_path],
              available_locales: [:en],
              separator: ".",
            )

            assert_empty(locations)
          end
        end
      end
    end
  end
end
