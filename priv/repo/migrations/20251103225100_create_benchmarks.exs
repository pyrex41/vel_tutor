defmodule ViralEngine.Repo.Migrations.CreateBenchmarks do
  use Ecto.Migration

  def change do
    create table(:benchmarks) do
      add(:name, :string, null: false)
      add(:prompt, :text, null: false)
      add(:providers, {:array, :string}, null: false)
      add(:results, :map)
      add(:stats, :map)
      add(:history, {:array, :map})
      add(:suite, :string)

      timestamps()
    end

    create(index(:benchmarks, [:suite]))
    create(index(:benchmarks, [:inserted_at]))
  end
end
