class CreateCachedPages < ActiveRecord::Migration
  def change
    create_table :cached_pages do |t|
      t.string :url
      t.text :content, :limit => 16777215
      t.datetime :valid_until

      t.timestamps
    end
  end
end
