class CreateDatabases < ActiveRecord::Migration
  def change
    create_table :databases do |t|
      t.string :name
      t.string :username
      t.integer :db_type
      t.integer :uid_number

      t.timestamps
    end
  end
end
