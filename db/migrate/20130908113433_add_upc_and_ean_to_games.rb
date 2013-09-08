class AddUpcAndEanToGames < ActiveRecord::Migration
  def change
    add_column :games, :upc, :string
    add_column :games, :ean, :string
  end
end
