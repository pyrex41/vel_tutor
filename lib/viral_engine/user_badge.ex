defmodule ViralEngine.UserBadge do
  @moduledoc """
  Schema for tracking user's earned badges.

  Represents the many-to-many relationship between users and badges,
  with additional metadata about when and how the badge was earned.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_badges" do
    field(:user_id, :integer)
    field(:badge_id, :integer)

    field(:unlocked_at, :utc_datetime)
    field(:progress, :integer, default: 0)      # Progress toward badge (if multi-step)
    field(:is_new, :boolean, default: true)     # For showing "NEW!" indicator
    field(:is_shared, :boolean, default: false)  # Has user shared this badge?
    field(:shared_at, :utc_datetime)

    field(:unlock_context, :map, default: %{})  # Additional context about unlock
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(user_badge, attrs) do
    user_badge
    |> cast(attrs, [
      :user_id,
      :badge_id,
      :unlocked_at,
      :progress,
      :is_new,
      :is_shared,
      :shared_at,
      :unlock_context,
      :metadata
    ])
    |> validate_required([:user_id, :badge_id])
    |> unique_constraint([:user_id, :badge_id], name: :user_badges_user_id_badge_id_index)
  end

  @doc """
  Marks a badge as viewed (no longer new).
  """
  def mark_viewed(user_badge) do
    changeset(user_badge, %{is_new: false})
  end

  @doc """
  Marks a badge as shared.
  """
  def mark_shared(user_badge) do
    changeset(user_badge, %{
      is_shared: true,
      shared_at: DateTime.utc_now()
    })
  end

  @doc """
  Updates badge progress.
  """
  def update_progress(user_badge, progress) do
    changeset(user_badge, %{progress: progress})
  end
end
