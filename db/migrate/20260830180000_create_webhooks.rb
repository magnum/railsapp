class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.string :state, default: "created"
      t.references :webhookable, polymorphic: true, index: true
      t.boolean :async, default: false
      t.string :url
      t.string :method
      t.jsonb :headers
      t.jsonb :body
      t.integer :response_code
      t.text :response_body
      t.jsonb :response_headers
      t.string :error_message
      t.string :error_backtrace
      t.timestamps
    end
  end
end
