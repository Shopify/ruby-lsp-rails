class CreateFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :flags do |t|
      t.references :country, null: false, foreign_key: true

      t.timestamps
    end
  end
end
