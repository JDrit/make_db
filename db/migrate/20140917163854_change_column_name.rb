class ChangeColumnName < ActiveRecord::Migration
  def change
    rename_column :databases, :uid_number, :entry_uuid
  end
end
