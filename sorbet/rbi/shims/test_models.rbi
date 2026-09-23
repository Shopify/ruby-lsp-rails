# typed: strict
# frozen_string_literal: true

# Models referenced by tests whose definitions are excluded via --ignore=test/dummy.
class ApplicationRecord < ActiveRecord::Base; end
class User < ApplicationRecord; end
