defmodule ViralEngine.XPContext do
  @moduledoc """
  Context module for managing XP (experience points) and rewards.

  Handles XP earning, level progression, and rewards shop functionality.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, UserXP, Reward, UserReward}
  require Logger

  @doc """
  Gets or creates a user's XP record.
  """
  def get_or_create_user_xp(user_id) do
    case Repo.get_by(UserXP, user_id: user_id) do
      nil ->
        %UserXP{}
        |> UserXP.changeset(%{user_id: user_id})
        |> Repo.insert()

      user_xp ->
        {:ok, user_xp}
    end
  end

  @doc """
  Grants XP to a user and handles level-ups.
  """
  def grant_xp(user_id, xp_amount, source \\ :general) when xp_amount > 0 do
    {:ok, user_xp} = get_or_create_user_xp(user_id)

    # Check for active XP boost powerups
    xp_multiplier = get_active_xp_multiplier(user_id)
    final_xp = round(xp_amount * xp_multiplier)

    # Update XP
    _new_current_xp = user_xp.current_xp + final_xp
    new_total_xp = user_xp.total_xp + final_xp

    # Calculate new level
    {new_level, remaining_xp, xp_to_next} = UserXP.level_from_xp(new_total_xp)

    # Check for level-up
    leveled_up = new_level > user_xp.level
    levels_gained = new_level - user_xp.level

    # Update XP sources breakdown
    xp_sources = user_xp.xp_sources
    source_key = Atom.to_string(source)
    current_source_xp = Map.get(xp_sources, source_key, 0)
    updated_sources = Map.put(xp_sources, source_key, current_source_xp + final_xp)

    # Update user XP record
    updated_attrs = %{
      current_xp: remaining_xp,
      total_xp: new_total_xp,
      level: new_level,
      xp_to_next_level: xp_to_next,
      lifetime_level_ups: user_xp.lifetime_level_ups + levels_gained,
      xp_sources: updated_sources
    }

    case Repo.update(UserXP.changeset(user_xp, updated_attrs)) do
      {:ok, updated_user_xp} ->
        Logger.info("Granted #{final_xp} XP to user #{user_id} (source: #{source}, multiplier: #{xp_multiplier}x)")

        # Broadcast level-up event if applicable
        if leveled_up do
          Logger.info("User #{user_id} leveled up! Level #{user_xp.level} → #{new_level}")

          Phoenix.PubSub.broadcast(
            ViralEngine.PubSub,
            "user:#{user_id}:xp",
            {:level_up, %{
              old_level: user_xp.level,
              new_level: new_level,
              levels_gained: levels_gained
            }}
          )
        end

        # Broadcast XP gain event
        Phoenix.PubSub.broadcast(
          ViralEngine.PubSub,
          "user:#{user_id}:xp",
          {:xp_gained, %{amount: final_xp, source: source, total_xp: new_total_xp}}
        )

        {:ok, updated_user_xp, leveled_up}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a user's XP record.
  """
  def get_user_xp(user_id) do
    get_or_create_user_xp(user_id)
  end

  @doc """
  Lists all active rewards.
  """
  def list_rewards(opts \\ []) do
    query = from(r in Reward,
      where: r.is_active == true,
      order_by: [asc: r.order, asc: r.xp_cost]
    )

    query = if opts[:reward_type] do
      from(r in query, where: r.reward_type == ^opts[:reward_type])
    else
      query
    end

    query = if opts[:max_xp_cost] do
      from(r in query, where: r.xp_cost <= ^opts[:max_xp_cost])
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets a reward by ID.
  """
  def get_reward(reward_id) do
    Repo.get(Reward, reward_id)
  end

  @doc """
  Creates a reward.
  """
  def create_reward(attrs) do
    %Reward{}
    |> Reward.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets user's claimed rewards.
  """
  def get_user_rewards(user_id, opts \\ []) do
    query = from(ur in UserReward,
      join: r in Reward, on: ur.reward_id == r.id,
      where: ur.user_id == ^user_id,
      order_by: [desc: ur.claimed_at],
      select: %{
        user_reward: ur,
        reward: r
      }
    )

    query = if opts[:is_equipped] do
      from([ur, r] in query, where: ur.is_equipped == true)
    else
      query
    end

    query = if opts[:is_active] do
      from([ur, r] in query, where: ur.is_active == true)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Claims a reward for a user (purchases from shop).
  """
  def claim_reward(user_id, reward_id) do
    with {:ok, user_xp} <- get_or_create_user_xp(user_id),
         reward <- get_reward(reward_id),
         :ok <- validate_claim(user_xp, reward) do

      # Deduct XP
      new_total_xp = user_xp.total_xp - reward.xp_cost
      {new_level, new_current_xp, new_xp_to_next} = UserXP.level_from_xp(new_total_xp)

      # Update user XP
      {:ok, updated_user_xp} = Repo.update(UserXP.changeset(user_xp, %{
        total_xp: new_total_xp,
        current_xp: new_current_xp,
        level: new_level,
        xp_to_next_level: new_xp_to_next
      }))

      # Create user reward record
      user_reward_attrs = %{
        user_id: user_id,
        reward_id: reward_id,
        claimed_at: DateTime.utc_now(),
        xp_spent: reward.xp_cost,
        uses_remaining: reward.metadata["uses"]
      }

      case Repo.insert(UserReward.changeset(%UserReward{}, user_reward_attrs)) do
        {:ok, user_reward} ->
          Logger.info("User #{user_id} claimed reward: #{reward.name} for #{reward.xp_cost} XP")

          # Update stock if limited
          if reward.is_limited && reward.stock do
            Repo.update(Reward.changeset(reward, %{stock: reward.stock - 1}))
          end

          # Broadcast reward claimed event
          Phoenix.PubSub.broadcast(
            ViralEngine.PubSub,
            "user:#{user_id}:rewards",
            {:reward_claimed, %{reward: reward, user_reward: user_reward}}
          )

          {:ok, user_reward, updated_user_xp}

        {:error, changeset} ->
          {:error, changeset}
      end

    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :reward_not_found}
    end
  end

  @doc """
  Equips a cosmetic reward.
  """
  def equip_reward(user_id, reward_id) do
    case get_user_reward(user_id, reward_id) do
      nil ->
        {:error, :not_owned}

      user_reward ->
        # Unequip other rewards of same type first
        reward = get_reward(reward_id)
        if reward.reward_type in ["avatar", "theme", "cosmetic"] do
          unequip_same_type_rewards(user_id, reward.reward_type)
        end

        user_reward
        |> UserReward.equip()
        |> Repo.update()
    end
  end

  @doc """
  Activates a powerup reward.
  """
  def activate_powerup(user_id, reward_id) do
    case get_user_reward(user_id, reward_id) do
      nil ->
        {:error, :not_owned}

      user_reward ->
        reward = get_reward(reward_id)
        duration = reward.metadata["duration_minutes"]

        user_reward
        |> UserReward.activate(duration)
        |> Repo.update()
    end
  end

  @doc """
  Seeds default rewards into the database.
  """
  def seed_default_rewards do
    Reward.default_rewards()
    |> Enum.each(fn reward_attrs ->
      case Repo.get_by(Reward, name: reward_attrs.name) do
        nil ->
          case create_reward(reward_attrs) do
            {:ok, reward} ->
              Logger.info("Seeded reward: #{reward.name}")

            {:error, changeset} ->
              Logger.error("Failed to seed reward #{reward_attrs.name}: #{inspect(changeset.errors)}")
          end

        _existing ->
          Logger.debug("Reward already exists: #{reward_attrs.name}")
      end
    end)
  end

  # Private functions

  defp validate_claim(_user_xp, nil), do: {:error, :reward_not_found}
  defp validate_claim(user_xp, reward) do
    cond do
      !reward.is_active ->
        {:error, :reward_inactive}

      reward.level_required > user_xp.level ->
        {:error, :level_too_low}

      reward.xp_cost > user_xp.total_xp ->
        {:error, :insufficient_xp}

      reward.is_limited && reward.stock && reward.stock <= 0 ->
        {:error, :out_of_stock}

      reward.expires_at && DateTime.compare(DateTime.utc_now(), reward.expires_at) == :gt ->
        {:error, :expired}

      true ->
        :ok
    end
  end

  defp get_user_reward(user_id, reward_id) do
    from(ur in UserReward,
      where: ur.user_id == ^user_id and ur.reward_id == ^reward_id
    )
    |> Repo.one()
  end

  defp unequip_same_type_rewards(user_id, reward_type) do
    from(ur in UserReward,
      join: r in Reward, on: ur.reward_id == r.id,
      where: ur.user_id == ^user_id and r.reward_type == ^reward_type and ur.is_equipped == true
    )
    |> Repo.update_all(set: [is_equipped: false])
  end

  defp get_active_xp_multiplier(user_id) do
    # Check for active XP boost powerups
    now = DateTime.utc_now()

    multipliers = from(ur in UserReward,
      join: r in Reward, on: ur.reward_id == r.id,
      where: ur.user_id == ^user_id and
             ur.is_active == true and
             r.reward_type == "powerup" and
             (is_nil(ur.expires_at) or ur.expires_at > ^now),
      select: fragment("CAST(? ->> 'multiplier' AS float)", r.metadata)
    )
    |> Repo.all()

    if length(multipliers) > 0 do
      Enum.max(multipliers)  # Use highest multiplier
    else
      1.0
    end
  end
end
