# Drops tables inherited from the communities project schema that this
# backend was bootstrapped from. A1C's data model is `doses` + `settings`
# only (see docs/03-data-model.md); nothing in this app ever used these.
class DropLegacyCommunityTables < ActiveRecord::Migration[8.1]
  # Order matters: dependents first, then their referenced tables.
  LEGACY_TABLES = %w[
    active_storage_variant_records
    active_storage_attachments
    active_storage_blobs
    evidences
    memberships
    sessions
    tries
    missions
    specialities
    groups
    invite_codes
    users
  ].freeze

  def up
    LEGACY_TABLES.each do |table|
      # CASCADE: some legacy tables have FKs between them (e.g. routes → tries)
      # that the original schema never dropped cleanly. The tables and their
      # constraints are all legacy objects being removed together.
      drop_table table, if_exists: true, force: :cascade if table_exists?(table)
    end
  end

  def down
    # Not reversible: these tables never belonged to A1C and hold no data.
    raise ActiveRecord::IrreversibleMigration
  end
end
