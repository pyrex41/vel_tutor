defmodule ViralEngine.ResultsRally do
  @moduledoc """
  Schema for Results Rally viral loop.

  Tracks cohort-based leaderboard challenges where users can invite others
  to compete on diagnostic results.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "results_rallies" do
    field(:creator_id, :integer)
    field(:rally_name, :string)
    field(:subject, :string)
    field(:grade_level, :integer)
    field(:rally_token, :string)  # For deep links

    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)
    field(:status, :string, default: "active")  # active, ended, archived

    field(:participant_count, :integer, default: 1)
    field(:invite_count, :integer, default: 0)

    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(rally, attrs) do
    rally
    |> cast(attrs, [
      :creator_id,
      :rally_name,
      :subject,
      :grade_level,
      :rally_token,
      :start_date,
      :end_date,
      :status,
      :participant_count,
      :invite_count,
      :metadata
    ])
    |> validate_required([:creator_id, :subject, :rally_token])
    |> validate_inclusion(:status, ["active", "ended", "archived"])
    |> validate_number(:grade_level, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> unique_constraint(:rally_token)
  end

  @doc """
  Checks if rally is currently active.
  """
  def active?(%__MODULE__{status: "active", end_date: nil}), do: true
  def active?(%__MODULE__{status: "active", end_date: end_date}) do
    DateTime.compare(DateTime.utc_now(), end_date) == :lt
  end
  def active?(_), do: false
end
