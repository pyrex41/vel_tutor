defmodule ViralEngine.BadgeContext do
  @moduledoc """
  Context module for managing badges and achievements.

  Handles badge unlocking, progress tracking, and achievement criteria evaluation.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, Badge, UserBadge, PracticeContext, DiagnosticContext, StreakContext}
  require Logger

  @doc """
  Lists all active badges.
  """
  def list_badges(opts \\ []) do
    query = from(b in Badge,
      where: b.is_active == true,
      order_by: [asc: b.order, asc: b.id]
    )

    query = if opts[:badge_type] do
      from(b in query, where: b.badge_type == ^opts[:badge_type])
    else
      query
    end

    query = if opts[:category] do
      from(b in query, where: b.category == ^opts[:category])
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets a badge by ID.
  """
  def get_badge(badge_id) do
    Repo.get(Badge, badge_id)
  end

  @doc """
  Creates a badge.
  """
  def create_badge(attrs) do
    %Badge{}
    |> Badge.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all badges earned by a user.
  """
  def get_user_badges(user_id, opts \\ []) do
    query = from(ub in UserBadge,
      join: b in Badge, on: ub.badge_id == b.id,
      where: ub.user_id == ^user_id,
      order_by: [desc: ub.unlocked_at],
      select: %{
        user_badge: ub,
        badge: b
      }
    )

    query = if opts[:is_new] do
      from([ub, b] in query, where: ub.is_new == true)
    else
      query
    end

    query = if opts[:limit] do
      from(q in query, limit: ^opts[:limit])
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets user's badge collection with progress.
  """
  def get_user_badge_collection(user_id) do
    # Get all active badges
    all_badges = list_badges()

    # Get user's earned badges
    earned = from(ub in UserBadge,
      where: ub.user_id == ^user_id,
      select: %{badge_id: ub.badge_id, unlocked_at: ub.unlocked_at, is_new: ub.is_new}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn ub, acc -> Map.put(acc, ub.badge_id, ub) end)

    # Combine
    Enum.map(all_badges, fn badge ->
      user_badge = Map.get(earned, badge.id)

      %{
        badge: badge,
        unlocked: user_badge != nil,
        unlocked_at: user_badge && user_badge.unlocked_at,
        is_new: user_badge && user_badge.is_new,
        progress: if(user_badge, do: 100, else: calculate_badge_progress(user_id, badge))
      }
    end)
  end

  @doc """
  Checks if a user has earned a specific badge.
  """
  def has_badge?(user_id, badge_id) do
    from(ub in UserBadge,
      where: ub.user_id == ^user_id and ub.badge_id == ^badge_id
    )
    |> Repo.exists?()
  end

  @doc """
  Unlocks a badge for a user.
  """
  def unlock_badge(user_id, badge_id, context \\ %{}) do
    # Check if already unlocked
    if has_badge?(user_id, badge_id) do
      {:error, :already_unlocked}
    else
      badge = get_badge(badge_id)

      if badge do
        attrs = %{
          user_id: user_id,
          badge_id: badge_id,
          unlocked_at: DateTime.utc_now(),
          unlock_context: context,
          is_new: true
        }

        case Repo.insert(UserBadge.changeset(%UserBadge{}, attrs)) do
          {:ok, user_badge} ->
            Logger.info("Badge unlocked: user_id=#{user_id}, badge=#{badge.name}")

            # Grant XP reward
            if badge.reward_xp > 0 do
              Logger.info("Granting #{badge.reward_xp} XP for badge: #{badge.name}")
              # TODO: Integrate with XP system when available
            end

            # Broadcast unlock event
            Phoenix.PubSub.broadcast(
              ViralEngine.PubSub,
              "user:#{user_id}:badges",
              {:badge_unlocked, %{badge: badge, user_badge: user_badge}}
            )

            {:ok, user_badge, badge}

          {:error, changeset} ->
            {:error, changeset}
        end
      else
        {:error, :badge_not_found}
      end
    end
  end

  @doc """
  Marks a user badge as viewed (no longer new).
  """
  def mark_badge_viewed(user_id, badge_id) do
    case get_user_badge(user_id, badge_id) do
      nil ->
        {:error, :not_found}

      user_badge ->
        user_badge
        |> UserBadge.mark_viewed()
        |> Repo.update()
    end
  end

  @doc """
  Marks a badge as shared.
  """
  def mark_badge_shared(user_id, badge_id) do
    case get_user_badge(user_id, badge_id) do
      nil ->
        {:error, :not_found}

      user_badge ->
        user_badge
        |> UserBadge.mark_shared()
        |> Repo.update()
    end
  end

  @doc """
  Checks all badge criteria for a user and unlocks eligible badges.
  """
  def check_and_unlock_badges(user_id, event_type \\ :general) do
    # Get all active badges user doesn't have
    unlocked_badge_ids = from(ub in UserBadge,
      where: ub.user_id == ^user_id,
      select: ub.badge_id
    )
    |> Repo.all()

    eligible_badges = from(b in Badge,
      where: b.is_active == true and b.id not in ^unlocked_badge_ids
    )
    |> Repo.all()

    # Check each badge's criteria
    newly_unlocked = Enum.reduce(eligible_badges, [], fn badge, acc ->
      if check_badge_criteria(user_id, badge) do
        case unlock_badge(user_id, badge.id, %{event_type: event_type}) do
          {:ok, user_badge, badge} ->
            [{user_badge, badge} | acc]

          {:error, _reason} ->
            acc
        end
      else
        acc
      end
    end)

    {:ok, newly_unlocked}
  end

  @doc """
  Seeds default badges into the database.
  """
  def seed_default_badges do
    Badge.default_badges()
    |> Enum.each(fn badge_attrs ->
      case Repo.get_by(Badge, name: badge_attrs.name) do
        nil ->
          case create_badge(badge_attrs) do
            {:ok, badge} ->
              Logger.info("Seeded badge: #{badge.name}")

            {:error, changeset} ->
              Logger.error("Failed to seed badge #{badge_attrs.name}: #{inspect(changeset.errors)}")
          end

        _existing ->
          Logger.debug("Badge already exists: #{badge_attrs.name}")
      end
    end)
  end

  # Private functions

  defp get_user_badge(user_id, badge_id) do
    from(ub in UserBadge,
      where: ub.user_id == ^user_id and ub.badge_id == ^badge_id
    )
    |> Repo.one()
  end

  defp calculate_badge_progress(user_id, badge) do
    case badge.criteria do
      %{"type" => "practice_sessions_completed", "threshold" => threshold} ->
        stats = PracticeContext.get_user_stats(user_id)
        sessions = stats.total_sessions || 0
        min(100, div(sessions * 100, threshold))

      %{"type" => "streak_reached", "threshold" => threshold} ->
        case StreakContext.get_user_streak(user_id) do
          {:ok, streak} ->
            current = streak.current_streak || 0
            min(100, div(current * 100, threshold))

          _ ->
            0
        end

      _ ->
        0  # Progress not available for this badge type
    end
  end

  defp check_badge_criteria(user_id, badge) do
    case badge.criteria do
      %{"type" => "practice_sessions_completed", "threshold" => threshold} ->
        stats = PracticeContext.get_user_stats(user_id)
        (stats.total_sessions || 0) >= threshold

      %{"type" => "streak_reached", "threshold" => threshold} ->
        case StreakContext.get_user_streak(user_id) do
          {:ok, streak} ->
            (streak.current_streak || 0) >= threshold

          _ ->
            false
        end

      %{"type" => "perfect_score", "threshold" => score} ->
        # Check if user has any assessment with perfect score
        assessments = DiagnosticContext.list_user_assessments(user_id, completed: true, limit: 100)
        Enum.any?(assessments, fn a -> (a.score || 0) >= score end)

      %{"type" => "high_scores", "threshold" => count, "min_score" => min_score} ->
        # Check if user has enough high-scoring assessments
        assessments = DiagnosticContext.list_user_assessments(user_id, completed: true, limit: 100)
        high_scores = Enum.count(assessments, fn a -> (a.score || 0) >= min_score end)
        high_scores >= count

      %{"type" => "challenges_sent"} ->
        # TODO: Integrate with ChallengeContext when check is needed
        false

      %{"type" => "rallies_created"} ->
        # TODO: Integrate with RallyContext when check is needed
        false

      %{"type" => "social_interactions", "threshold" => threshold} ->
        # TODO: Integrate with social contexts
        false

      %{"type" => "practice_before_hour", "threshold" => hour} ->
        # Check if any practice session completed before specified hour
        # This would need to be triggered at session completion
        false

      %{"type" => "practice_after_hour", "threshold" => hour} ->
        # Check if any practice session completed after specified hour
        # This would need to be triggered at session completion
        false

      %{"type" => "streak_rescued"} ->
        # TODO: Integrate with streak rescue tracking
        false

      %{"type" => "parent_shares"} ->
        # TODO: Integrate with ParentShareContext
        false

      _ ->
        Logger.warning("Unknown badge criteria type: #{inspect(badge.criteria)}")
        false
    end
  end
end
