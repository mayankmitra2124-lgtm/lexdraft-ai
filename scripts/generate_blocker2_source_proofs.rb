# frozen_string_literal: true

require 'sqlite3'
require 'digest'
require 'json'
require_relative '../db/migrate_sqlite_to_pg'

db = SQLite3::Database.new('case_organizer.db')
db.results_as_hash = true

tables = MigrationRunner::TABLE_ORDER

source_proofs = {}

tables.each do |tbl|
  rows = db.execute("SELECT * FROM #{tbl}")
  
  # Determine primary key column
  table_info = db.execute("PRAGMA table_info(#{tbl})")
  pk_col = table_info.find { |col| col['pk'].to_i > 0 }
  pk_name = pk_col ? pk_col['name'] : 'id'

  # Extract PK set
  pk_set = rows.map { |r| r[pk_name].to_s }.sort
  pk_set_hash = Digest::SHA256.hexdigest(pk_set.join(','))

  # Calculate canonical row hash
  canonical_table_hash = MigrationRunner.calculate_table_checksum(db, tbl)

  source_proofs[tbl] = {
    row_count: rows.size,
    primary_key_column: pk_name,
    primary_key_count: pk_set.size,
    primary_key_set_sha256: pk_set_hash,
    canonical_row_hash: canonical_table_hash,
    sample_pks: pk_set.first(3)
  }
end

integrity = MigrationRunner.verify_integrity!

output = {
  database_source: "case_organizer.db (Authoritative SQLite Source of Record)",
  timestamp: Time.now.utc.iso8601,
  total_tables: tables.size,
  integrity_checks: integrity,
  tables: source_proofs
}

File.write('scratch/blocker2_source_proofs.json', JSON.pretty_generate(output))
puts JSON.pretty_generate(output)
