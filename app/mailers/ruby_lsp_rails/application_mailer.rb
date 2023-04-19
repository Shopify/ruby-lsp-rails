# typed: strict
# frozen_string_literal: true

module RubyLspRails
  class ApplicationMailer < ActionMailer::Base
    default from: "from@example.com"
    layout "mailer"
  end
end
