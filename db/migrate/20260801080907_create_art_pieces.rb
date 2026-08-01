class CreateArtPieces < ActiveRecord::Migration[8.0]
  def change
    create_table :art_pieces, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text   :description
      # Pricing is optional and display-only — this is a portfolio, not a store.
      # precision 12 / scale 2 comfortably covers currencies with large units.
      t.decimal :price_amount, precision: 12, scale: 2
      t.string  :price_currency_symbol
      t.string  :price_currency_name
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :art_pieces, [ :project_id, :position ]
  end
end
