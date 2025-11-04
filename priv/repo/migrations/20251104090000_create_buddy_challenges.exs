defmodule ViralEngine.Repo.Migrations.CreateBuddyChallenges do
  use Ecto.Migration

  def change do
    create table(:buddy_challenges) do
      add :challenger_id, :integer, null: false
      add :challenged_user_id, :integer
      add :challenged_email, :string
      add :session_id, :integer, null: false
      add :subject, :string, null: false
      add :challenger_score, :integer, null: false
      add :challenged_score, :integer

      add :challenge_token, :string, null: false
      add :status, :string, null: false, default: "pending"

      add :expires_at, :utc_datetime
      add :accepted_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :reward_granted, :boolean, default: false
      add :winner_id, :integer

      add :share_method, :string
      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique token index
    create unique_index(:buddy_challenges, [:challenge_token])

    # Query indexes
    create index(:buddy_challenges, [:challenger_id])
    create index(:buddy_challenges, [:challenged_user_id])
    create index(:buddy_challenges, [:status])
    create index(:buddy_challenges, [:challenger_id, :status])
    create index(:buddy_challenges, [:challenged_user_id, :status])

    # Expiry cleanup index
    create index(:buddy_challenges, [:status, :expires_at])
  end
end
