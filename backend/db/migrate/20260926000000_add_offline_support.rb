class AddOfflineSupport < ActiveRecord::Migration[8.1]
  def change
    # Real injection moment. Nullable: server-timed doses keep using created_at.
    add_column :doses, :taken_at, :datetime
    # Client-generated UUID for idempotent retries (offline sync).
    add_column :doses, :client_id, :string
    add_index  :doses, :client_id, unique: true

    # IANA zone used for day bucketing of the graph (default: Monterrey).
    add_column :settings, :timezone, :string, default: "America/Monterrey", null: false
  end
end
