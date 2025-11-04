defmodule ViralEngine.UserStreak do
  @moduledoc """
  Schema for tracking user learning streaks.

  Tracks consecutive days of practice and detects at-risk streaks.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_streaks" do
    field(:user_id, :integer)
    field(:current_streak, :integer, default: 0)
    field(:longest_streak, :integer, default: 0)
    field(:last_activity_date, :date)
    field(:next_deadline, :utc_datetime)  # When streak will break
    field(:streak_at_risk, :boolean, default: false)
    field(:rescue_sent, :boolean, default: false)
    field(:rescue_sent_at, :utc_datetime)

    timestamps()
  end

  def changeset(streak, attrs) do
    streak
    |> cast(attrs, [
      :user_id,
      :current_streak,
      :longest_streak,
      :last_activity_date,
      :next_deadline,
      :streak_at_risk,
      :rescue_sent,
      :rescue_sent_at
    ])
    |> validate_required([:user_id])
    |> validate_number(:current_streak, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
  end

  @doc """
  Checks if streak is at risk (deadline within 6 hours).
  """
  def at_risk?(%__MODULE__{next_deadline: nil}), do: false
  def at_risk?(%__MODULE__{next_deadline: deadline}) do
    now = DateTime.utc_now()
    hours_remaining = DateTime.diff(deadline, now, :hour)
    hours_remaining > 0 && hours_remaining <= 6
  end

  @doc """
  Checks if streak is broken (past deadline).
  """
  def broken?(%__MODULE__{next_deadline: nil}), do: false
  def broken?(%__MODULE__{next_deadline: deadline}) do
    DateTime.compare(DateTime.utc_now(), deadline) == :gt
  end
end
