class AddComplexIndexToUsers < ActiveRecord::Migration[8.0]
  def change
    execute "CREATE UNIQUE INDEX users_unique_complex ON users (COALESCE(country_id, 0), ltrim(first_name));"
  end
end
