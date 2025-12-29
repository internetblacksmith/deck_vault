class RenameEmailToUsernameInUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :email, :username
  end
end
