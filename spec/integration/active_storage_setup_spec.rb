require "rails_helper"

# Guards the Phase 0 storage foundation: Active Storage tables exist, use uuid
# keys like the rest of the schema, and the disk service round-trips a file.
RSpec.describe "Active Storage setup" do
  it "uses uuid primary keys on its tables" do
    %w[active_storage_blobs active_storage_attachments active_storage_variant_records].each do |table|
      column = ActiveRecord::Base.connection.columns(table).find { |c| c.name == "id" }

      expect(column.sql_type).to eq("uuid"), "expected #{table}.id to be uuid, got #{column.sql_type}"
    end
  end

  it "stores and reads back an attached file" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image bytes"),
      filename: "piece.png",
      content_type: "image/png"
    )

    expect(blob.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    expect(blob.download).to eq("fake image bytes")
  end

  it "uses a local disk service" do
    expect(ActiveStorage::Blob.service).to be_a(ActiveStorage::Service::DiskService)
  end
end
