# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :tenant_id, null: false
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
