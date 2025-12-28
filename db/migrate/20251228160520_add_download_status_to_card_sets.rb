class AddDownloadStatusToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :download_status, :string, default: "pending"
    add_column :card_sets, :images_downloaded, :integer, default: 0
  end
end
