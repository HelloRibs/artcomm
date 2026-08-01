class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :title, null: false
      t.string  :slug, null: false
      t.text    :description
      t.boolean :published, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # Slugs only need to be unique within an artist's own URL space.
    add_index :projects, [ :user_id, :slug ], unique: true
    add_index :projects, [ :user_id, :position ]
  end
end
