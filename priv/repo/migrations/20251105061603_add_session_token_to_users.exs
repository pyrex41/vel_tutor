defmodule ViralEngine.Repo.Migrations.AddSessionTokenToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:session_token, :string)
    end

    create(unique_index(:users, [:session_token], where: "session_token IS NOT NULL"))
  end
end
