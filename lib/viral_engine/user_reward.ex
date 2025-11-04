defmodule ViralEngine.UserReward do
  @moduledoc """
  Schema for tracking rewards claimed by users.

  Represents which rewards users have purchased/unlocked from the rewards shop.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_rewards" do
    field(:user_id, :integer)
    field(:reward_id, :integer)

    field(:claimed_at, :utc_datetime)
    field(:xp_spent, :integer)

    field(:is_equipped, :boolean, default: false)  # For cosmetic items
    field(:is_active, :boolean, default: false)    # For powerups
    field(:uses_remaining, :integer)               # For consumable powerups
    field(:expires_at, :utc_datetime)              # For time-limited powerups

    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(user_reward, attrs) do
    user_reward
    |> cast(attrs, [
      :user_id,
      :reward_id,
      :claimed_at,
      :xp_spent,
      :is_equipped,
      :is_active,
      :uses_remaining,
      :expires_at,
      :metadata
    ])
    |> validate_required([:user_id, :reward_id, :xp_spent])
  end

  @doc """
  Marks a cosmetic reward as equipped.
  """
  def equip(user_reward) do
    changeset(user_reward, %{is_equipped: true})
  end

  @doc """
  Unequips a cosmetic reward.
  """
  def unequip(user_reward) do
    changeset(user_reward, %{is_equipped: false})
  end

  @doc """
  Activates a powerup reward.
  """
  def activate(user_reward, duration_minutes \\ nil) do
    attrs = %{is_active: true}

    attrs = if duration_minutes do
      Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), duration_minutes * 60, :second))
    else
      attrs
    end

    changeset(user_reward, attrs)
  end

  @doc """
  Deactivates a powerup reward.
  """
  def deactivate(user_reward) do
    changeset(user_reward, %{is_active: false})
  end

  @doc """
  Uses one charge of a consumable powerup.
  """
  def use_charge(user_reward) do
    if user_reward.uses_remaining && user_reward.uses_remaining > 0 do
      changeset(user_reward, %{uses_remaining: user_reward.uses_remaining - 1})
    else
      {:error, :no_uses_remaining}
    end
  end

  @doc """
  Checks if a powerup is expired.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end
