defmodule ViralEngine.Cohort do
  @moduledoc """
  Represents a cohort of users for viral loop analysis.

  Cohorts are time-based groups of users (typically 14 days) used to measure
  viral growth metrics like K-factor, retention curves, and conversion funnels.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "cohorts" do
    field :cohort_id, :string
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :filters, :map, default: %{}
    field :user_count, :integer, default: 0
    field :k_factor, :float
    field :retention_curve, :map
    field :funnel_metrics, :map
    field :ltv_delta, :decimal
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc """
  Creates a changeset for a cohort.

  ## Required fields
  - cohort_id: Unique identifier (e.g., "2025-11-05-referred")
  - start_date: Beginning of cohort period
  - end_date: End of cohort period

  ## Optional fields
  - filters: Map of cohort filters (e.g., %{referred: true, source: "progress_reel"})
  - user_count: Number of users in cohort
  - k_factor: Calculated viral coefficient
  - retention_curve: Map of retention by day (e.g., %{day_1: 0.8, day_7: 0.5})
  - funnel_metrics: Conversion funnel data
  - ltv_delta: Lifetime value difference vs baseline
  - metadata: Additional cohort information
  """
  def changeset(cohort, attrs) do
    cohort
    |> cast(attrs, [
      :cohort_id,
      :start_date,
      :end_date,
      :filters,
      :user_count,
      :k_factor,
      :retention_curve,
      :funnel_metrics,
      :ltv_delta,
      :metadata
    ])
    |> validate_required([:cohort_id, :start_date, :end_date])
    |> validate_number(:user_count, greater_than_or_equal_to: 0)
    |> validate_date_range()
    |> unique_constraint(:cohort_id)
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && DateTime.compare(start_date, end_date) != :lt do
      add_error(changeset, :end_date, "must be after start_date")
    else
      changeset
    end
  end
end
