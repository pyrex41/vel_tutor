defmodule ViralEngine.Batch do
  @moduledoc """
  Schema for batch task operations, allowing users to submit and manage multiple tasks.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "batches" do
    field(:user_id, :integer)
    field(:organization_id, :integer)
    field(:name, :string)
    field(:tasks, :map)
    field(:status, :string, default: "pending")
    field(:concurrency_limit, :integer, default: 20)
    field(:completed_count, :integer, default: 0)
    field(:total_count, :integer, default: 0)
    field(:results, :map, default: %{})
    field(:error_count, :integer, default: 0)
    field(:metadata, :map)

    timestamps()
  end

  @required_fields [:user_id, :name, :tasks]
  @optional_fields [
    :organization_id,
    :status,
    :concurrency_limit,
    :completed_count,
    :total_count,
    :results,
    :error_count,
    :metadata
  ]

  @valid_statuses ~w(pending running completed cancelled failed)

  def changeset(batch, attrs) do
    batch
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:concurrency_limit, greater_than: 0, less_than_or_equal_to: 50)
    |> validate_tasks()
  end

  defp validate_tasks(changeset) do
    case get_change(changeset, :tasks) do
      nil ->
        changeset

      tasks when is_map(tasks) ->
        if Map.has_key?(tasks, "items") and is_list(tasks["items"]) and length(tasks["items"]) > 0 do
          # Set total_count based on tasks array length
          put_change(changeset, :total_count, length(tasks["items"]))
        else
          add_error(changeset, :tasks, "must contain an 'items' array with at least one task")
        end

      _ ->
        add_error(changeset, :tasks, "must be a map with 'items' array")
    end
  end
end
