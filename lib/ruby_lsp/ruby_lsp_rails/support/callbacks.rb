# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Rails
    module Support
      module Callbacks
        MODEL_CALLBACKS = T.let(
          [
            "before_validation",
            "after_validation",
            "before_save",
            "around_save",
            "after_save",
            "before_create",
            "around_create",
            "after_create",
            "after_commit",
            "after_rollback",
            "before_update",
            "around_update",
            "after_update",
            "before_destroy",
            "around_destroy",
            "after_destroy",
            "after_initialize",
            "after_find",
            "after_touch",
          ].freeze,
          T::Array[String],
        )

        CONTROLLER_CALLBACKS = T.let(
          [
            "after_action",
            "append_after_action",
            "append_around_action",
            "append_before_action",
            "around_action",
            "before_action",
            "prepend_after_action",
            "prepend_around_action",
            "prepend_before_action",
            "skip_after_action",
            "skip_around_action",
            "skip_before_action",
          ].freeze,
          T::Array[String],
        )

        JOB_CALLBACKS = T.let(
          [
            "after_enqueue",
            "after_perform",
            "around_enqueue",
            "around_perform",
            "before_enqueue",
            "before_perform",
          ].freeze,
          T::Array[String],
        )

        CALLBACKS = T.let((MODEL_CALLBACKS + CONTROLLER_CALLBACKS + JOB_CALLBACKS).freeze, T::Array[String])
      end
    end
  end
end
