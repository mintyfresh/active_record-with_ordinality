# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    tenant_id { 1 }
    name { Faker::Name.name }
  end
end
