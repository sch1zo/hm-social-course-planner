class CreateAuthentications < ActiveRecord::Migration
  def change
    create_table :authentications do |t|
      t.belongs_to :user
      t.string :provider
      t.string :uid

      t.timestamps
    end
    add_index :authentications, :user_id
  end
end
