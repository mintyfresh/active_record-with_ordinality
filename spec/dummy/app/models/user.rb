# frozen_string_literal: true

class User < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }

  alias_attribute :tenant, :tenant_id

  validates :tenant_id, :name, presence: true
end
