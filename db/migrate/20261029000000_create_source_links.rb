# Which source IDs each venue, act and gig came from, one row each, in place
# of the external_ids JSON. A record can hold several IDs from one source (a
# show Eventfinda lists twice), and lookups use a plain unique index.
class CreateSourceLinks < ActiveRecord::Migration[8.1]
  TABLES = { "Venue" => :venues, "Act" => :acts, "Gig" => :gigs }.freeze

  def up
    create_table :source_links do |t|
      t.string :source, null: false
      t.string :external_id, null: false
      t.references :linkable, polymorphic: true, null: false, index: false
      t.timestamps
    end
    add_index :source_links, [ :linkable_type, :source, :external_id ], unique: true, name: "index_source_links_on_external_id"
    add_index :source_links, [ :linkable_type, :linkable_id ]

    # Copy the IDs over; where two records claimed the same ID, the older keeps it
    TABLES.each do |type, table|
      execute <<~SQL
        INSERT INTO source_links (source, external_id, linkable_type, linkable_id, created_at, updated_at)
        SELECT ids.key, ids.value, '#{type}', #{table}.id, #{table}.created_at, NOW()
        FROM #{table}, jsonb_each_text(#{table}.external_ids) AS ids
        WHERE ids.value <> ''
        ORDER BY #{table}.id
        ON CONFLICT (linkable_type, source, external_id) DO NOTHING
      SQL
      remove_column table, :external_ids
    end

    add_column :venues, :match_key, :string
    add_column :acts, :match_key, :string
    add_index :venues, :match_key
    add_index :acts, :match_key

    say_with_time "Computing match keys" do
      select_rows("SELECT id, name, city FROM venues").each do |id, name, city|
        connection.execute(sanitize([ "UPDATE venues SET match_key = ? WHERE id = ?", MatchKey.venue(name, city), id ]))
      end
      select_rows("SELECT id, name FROM acts").each do |id, name|
        connection.execute(sanitize([ "UPDATE acts SET match_key = ? WHERE id = ?", MatchKey.act(name), id ]))
      end
    end
  end

  def down
    TABLES.each_value { |table| add_column table, :external_ids, :jsonb, default: {} }
    TABLES.each do |type, table|
      execute <<~SQL
        UPDATE #{table} SET external_ids = links.ids
        FROM (SELECT linkable_id, jsonb_object_agg(source, external_id) AS ids FROM source_links
              WHERE linkable_type = '#{type}' GROUP BY linkable_id) links
        WHERE links.linkable_id = #{table}.id
      SQL
      add_index table, :external_ids, using: :gin
    end
    remove_column :venues, :match_key
    remove_column :acts, :match_key
    drop_table :source_links
  end

  private

  def sanitize(sql) = ActiveRecord::Base.sanitize_sql_array(sql)
end
