defmodule ViralEngine.Repo.Migrations.CreateParentShares do
  use Ecto.Migration

  def change do
    create table(:parent_shares) do
      add :student_id, :integer, null: false
      add :parent_email, :string
      add :share_token, :string, null: false
      add :share_type, :string, null: false

      add :progress_data, :map, default: "{}"
      add :metadata, :map, default: "{}"

      add :viewed, :boolean, default: false
      add :viewed_at, :utc_datetime
      add :shared_at, :utc_datetime, null: false

      add :referral_used, :boolean, default: false
      add :referral_reward_granted, :boolean, default: false

      add :expires_at, :utc_datetime
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    # Unique token index
    create unique_index(:parent_shares, [:share_token])

    # Query indexes
    create index(:parent_shares, [:student_id])
    create index(:parent_shares, [:status])
    create index(:parent_shares, [:share_type])
    create index(:parent_shares, [:student_id, :share_type])

    # Expiry cleanup index
    create index(:parent_shares, [:status, :expires_at])

    # Referral tracking
    create index(:parent_shares, [:referral_used, :referral_reward_granted])
  end
end
