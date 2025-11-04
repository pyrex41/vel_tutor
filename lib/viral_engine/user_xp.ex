defmodule ViralEngine.UserXP do
  @moduledoc """
  Schema for tracking user's XP (experience points) and level progression.

  XP is earned through various activities: completing sessions, earning badges,
  maintaining streaks, social interactions, etc.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_xp" do
    field(:user_id, :integer)

    field(:current_xp, :integer, default: 0)
    field(:total_xp, :integer, default: 0)  # All-time XP earned
    field(:level, :integer, default: 1)

    field(:xp_to_next_level, :integer, default: 100)
    field(:lifetime_level_ups, :integer, default: 0)

    field(:xp_sources, :map, default: %{})  # Breakdown by source
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(user_xp, attrs) do
    user_xp
    |> cast(attrs, [
      :user_id,
      :current_xp,
      :total_xp,
      :level,
      :xp_to_next_level,
      :lifetime_level_ups,
      :xp_sources,
      :metadata
    ])
    |> validate_required([:user_id])
    |> validate_number(:current_xp, greater_than_or_equal_to: 0)
    |> validate_number(:level, greater_than_or_equal_to: 1)
    |> unique_constraint(:user_id)
  end

  @doc """
  Calculates XP required for a given level.

  Formula: 100 * level^1.5 (exponential growth)
  - Level 1 → 2: 100 XP
  - Level 2 → 3: 283 XP
  - Level 3 → 4: 520 XP
  - Level 4 → 5: 800 XP
  - Level 10 → 11: 3,162 XP
  """
  def xp_for_level(level) when level > 0 do
    round(100 * :math.pow(level, 1.5))
  end

  @doc """
  Calculates level from total XP.
  """
  def level_from_xp(total_xp) do
    calculate_level(total_xp, 1, 0)
  end

  defp calculate_level(total_xp, level, accumulated_xp) do
    xp_needed = xp_for_level(level)

    if accumulated_xp + xp_needed > total_xp do
      {level, total_xp - accumulated_xp, xp_needed}
    else
      calculate_level(total_xp, level + 1, accumulated_xp + xp_needed)
    end
  end

  @doc """
  Returns level title based on level.
  """
  def level_title(level) do
    cond do
      level >= 50 -> "Grandmaster"
      level >= 40 -> "Master"
      level >= 30 -> "Expert"
      level >= 20 -> "Veteran"
      level >= 10 -> "Adept"
      level >= 5 -> "Apprentice"
      true -> "Novice"
    end
  end

  @doc """
  Returns progress percentage to next level.
  """
  def progress_percentage(%__MODULE__{current_xp: current, xp_to_next_level: needed}) do
    if needed > 0 do
      Float.round(current / needed * 100, 1)
    else
      100.0
    end
  end
end
