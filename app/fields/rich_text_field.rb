# frozen_string_literal: true

require "administrate/field/base"

class RichTextField < Administrate::Field::Base
  def to_s
    data
  end

  def resource_label
    resource.try(:title).presence || resource.to_s
  end

  def resource_show_url
    return resource.public_path if resource.respond_to?(:public_path)

    [ :admin, resource ]
  end
end
