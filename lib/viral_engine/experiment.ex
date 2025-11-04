defmodule ViralEngine.Experiment do
  @moduledoc """
  Schema for A/B testing experiments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "experiments" do
    field(:name, :string)
    field(:description, :string)
    field(:experiment_key, :string)

    field(:status, :string, default: "draft")
    # draft, running, paused, completed

    field(:variants, :map, default: %{})
    # %{"control" => %{weight: 50}, "variant_a" => %{weight: 50}}

    field(:target_metric, :string)
    field(:success_criteria, :map, default: %{})

    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)

    field(:traffic_allocation, :integer, default: 100)  # Percentage
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [
      :name,
      :description,
      :experiment_key,
      :status,
      :variants,
      :target_metric,
      :success_criteria,
      :start_date,
      :end_date,
      :traffic_allocation,
      :metadata
    ])
    |> validate_required([:name, :experiment_key, :variants])
    |> validate_inclusion(:status, ["draft", "running", "paused", "completed"])
    |> unique_constraint(:experiment_key)
  end

  @doc """
  Assigns user to variant based on weighted random selection.
  """
  def assign_variant(%__MODULE__{variants: variants}, user_id) do
    # Deterministic assignment based on user_id hash
    hash = :erlang.phash2(user_id, 100)

    # Sort variants by key for consistency
    sorted_variants = Enum.sort_by(variants, fn {k, _v} -> k end)

    # Calculate cumulative weights
    {_acc, assigned} = Enum.reduce(sorted_variants, {0, nil}, fn {variant_name, config}, {cumulative, result} ->
      weight = config["weight"] || 0

      if result do
        {cumulative + weight, result}
      else
        if hash < cumulative + weight do
          {cumulative + weight, variant_name}
        else
          {cumulative + weight, nil}
        end
      end
    end)

    assigned || elem(hd(sorted_variants), 0)  # Fallback to first variant
  end
end
