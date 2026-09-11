# frozen_string_literal: true

class WorkspaceField < Administrate::Field::BelongsTo
  def include_blank_option
    options.fetch(:include_blank, false)
  end
end
