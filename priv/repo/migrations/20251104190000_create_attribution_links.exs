defmodule ViralEngine.Repo.Migrations.CreateAttributionLinks do
  use Ecto.Migration

  def change do
    create table(:attribution_links) do
      add(:link_token, :string, null: false)
      add(:link_signature, :string, null: false)

      add(:referrer_id, :integer, null: false)
      add(:campaign, :string)
      add(:source, :string, null: false)

      add(:target_url, :string)
      add(:metadata, :map, default: "{}")

      add(:click_count, :integer, default: 0)
      add(:unique_clicks, :integer, default: 0)
      add(:conversion_count, :integer, default: 0)

      add(:expires_at, :utc_datetime)
      add(:is_active, :boolean, default: true)

      timestamps()
    end

    create(unique_index(:attribution_links, [:link_token]))
    create(index(:attribution_links, [:referrer_id]))
    create(index(:attribution_links, [:source]))
    create(index(:attribution_links, [:campaign]))
    create(index(:attribution_links, [:inserted_at]))

    create table(:attribution_events) do
      add(:link_id, :integer, null: false)
      add(:event_type, :string, null: false)
      add(:user_id, :integer)
      add(:session_id, :string)

      add(:device_fingerprint, :string)
      add(:ip_address, :string)
      add(:user_agent, :text)

      add(:referrer_url, :string)
      add(:landing_page, :string)

      add(:metadata, :map, default: "{}")
      add(:converted, :boolean, default: false)
      add(:conversion_value, :decimal)

      timestamps()
    end

    create(index(:attribution_events, [:link_id]))
    create(index(:attribution_events, [:user_id]))
    create(index(:attribution_events, [:event_type]))
    create(index(:attribution_events, [:device_fingerprint]))
    create(index(:attribution_events, [:inserted_at]))
  end
end
