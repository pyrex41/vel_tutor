defmodule ViralEngine.ExperimentAssignment do
  @moduledoc """
  Schema for tracking experiment assignments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "experiment_assignments" do
    field(:experiment_id, :integer)
    field(:user_id, :integer)
    field(:variant, :string)

    field(:assigned_at, :utc_datetime)
    field(:exposed_at, :utc_datetime)
    field(:converted, :boolean, default: false)
    field(:conversion_value, :decimal)
    field(:conversion_at, :utc_datetime)

    field(:metrics, :map, default: %{})

    timestamps()
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :experiment_id,
      :user_id,
      :variant,
      :assigned_at,
      :exposed_at,
      :converted,
      :conversion_value,
      :conversion_at,
      :metrics
    ])
    |> validate_required([:experiment_id, :user_id, :variant])
    |> unique_constraint([:experiment_id, :user_id])
  end

  def mark_converted(assignment, value \\ nil) do
    changeset(assignment, %{
      converted: true,
      conversion_value: value,
      conversion_at: DateTime.utc_now()
    })
  end
end
