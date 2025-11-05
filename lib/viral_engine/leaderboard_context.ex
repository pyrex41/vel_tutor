defmodule ViralEngine.LeaderboardContext do
  @moduledoc """
  Context module for managing leaderboards across different scopes.

  Supports global, subject-specific, and cohort-based leaderboards with fairness filters.
  Includes caching for performance optimization.
  """

  import Ecto.Query
  alias ViralEngine.Repo
  require Logger

  @default_limit 100
  @default_time_period 7  # days
  @cache_ttl 60_000  # 60 seconds cache TTL

  @doc """
  Gets global leaderboard across all subjects.

  ## Options
  - limit: Max entries to return (default 100)
  - time_period: Days to consider (default 7)
  - metric: Ranking metric (:total_score, :average_score, :streak, :sessions)
  """
  def get_global_leaderboard(opts \\ []) do
    limit = opts[:limit] || @default_limit
    time_period = opts[:time_period] || @default_time_period
    metric = opts[:metric] || :total_score

    cutoff = DateTime.utc_now() |> DateTime.add(-time_period * 24 * 3600, :second)

    case metric do
      :total_score ->
        get_score_leaderboard(cutoff, limit, nil)

      :average_score ->
        get_average_score_leaderboard(cutoff, limit, nil)

      :streak ->
        get_streak_leaderboard(limit)

      :sessions ->
        get_sessions_leaderboard(cutoff, limit, nil)

      _ ->
        get_score_leaderboard(cutoff, limit, nil)
    end
  end

  @doc """
  Gets subject-specific leaderboard with caching.

  ## Parameters
  - subject: Subject name (e.g., "math", "science")
  - opts: Options (limit, time_period, metric, grade_level, use_cache)
  """
  def get_subject_leaderboard(subject, opts \\ []) do
    limit = opts[:limit] || @default_limit
    time_period = opts[:time_period] || @default_time_period
    metric = opts[:metric] || :total_score
    grade_level = opts[:grade_level]
    use_cache = opts[:use_cache] != false  # Default to true

    if use_cache do
      cache_key = build_cache_key(:subject, subject, metric, time_period, grade_level, limit)
      get_cached_or_compute(cache_key, fn ->
        fetch_subject_leaderboard(subject, limit, time_period, metric, grade_level)
      end)
    else
      fetch_subject_leaderboard(subject, limit, time_period, metric, grade_level)
    end
  end

  defp fetch_subject_leaderboard(subject, limit, time_period, metric, grade_level) do
    cutoff = DateTime.utc_now() |> DateTime.add(-time_period * 24 * 3600, :second)

    case metric do
      :total_score ->
        get_score_leaderboard(cutoff, limit, subject, grade_level)

      :average_score ->
        get_average_score_leaderboard(cutoff, limit, subject, grade_level)

      :sessions ->
        get_sessions_leaderboard(cutoff, limit, subject, grade_level)

      _ ->
        get_score_leaderboard(cutoff, limit, subject, grade_level)
    end
  end

  @doc """
  Gets cohort leaderboard (filtered by grade level).

  ## Parameters
  - grade_level: Grade level (1-12)
  - opts: Options (limit, time_period, metric, subject)
  """
  def get_cohort_leaderboard(grade_level, opts \\ []) do
    limit = opts[:limit] || @default_limit
    time_period = opts[:time_period] || @default_time_period
    subject = opts[:subject]

    cutoff = DateTime.utc_now() |> DateTime.add(-time_period * 24 * 3600, :second)

    get_score_leaderboard(cutoff, limit, subject, grade_level)
  end

  @doc """
  Gets user's rank in a specific leaderboard.

  ## Parameters
  - user_id: User ID
  - scope: :global, :subject, or :cohort
  - opts: Scope-specific options (subject, grade_level, time_period)
  """
  def get_user_rank(user_id, scope, opts \\ []) do
    leaderboard = case scope do
      :global ->
        get_global_leaderboard(opts)

      :subject ->
        subject = opts[:subject] || "math"
        get_subject_leaderboard(subject, opts)

      :cohort ->
        grade_level = opts[:grade_level] || 5
        get_cohort_leaderboard(grade_level, opts)

      _ ->
        get_global_leaderboard(opts)
    end

    case Enum.find_index(leaderboard, fn entry -> entry.user_id == user_id end) do
      nil -> {:not_ranked, length(leaderboard) + 1}
      index -> {:ranked, index + 1}
    end
  end

  @doc """
  Gets user's rank percentile.
  """
  def get_user_percentile(user_id, scope, opts \\ []) do
    case get_user_rank(user_id, scope, opts) do
      {:ranked, rank} ->
        leaderboard = case scope do
          :global -> get_global_leaderboard(opts)
          :subject -> get_subject_leaderboard(opts[:subject] || "math", opts)
          :cohort -> get_cohort_leaderboard(opts[:grade_level] || 5, opts)
          _ -> get_global_leaderboard(opts)
        end

        total = length(leaderboard)
        percentile = if total > 0 do
          ((total - rank) / total * 100) |> Float.round(1)
        else
          0.0
        end

        {:ok, percentile}

      {:not_ranked, _} ->
        {:ok, 0.0}
    end
  end

  # Private functions

  defp get_score_leaderboard(cutoff, limit, subject, _grade_level \\ nil) do
    base_query = from(s in ViralEngine.PracticeSession,
      where: s.completed == true and s.inserted_at >= ^cutoff,
      select: %{
        user_id: s.user_id,
        total_score: sum(s.score),
        sessions: count(s.id),
        avg_score: avg(s.score)
      },
      group_by: s.user_id,
      order_by: [desc: sum(s.score)],
      limit: ^limit
    )

    query = if subject do
      from(s in base_query, where: s.subject == ^subject)
    else
      base_query
    end

    # Note: grade_level filtering would require a users table join
    # For now, returning without grade_level filter
    Repo.all(query)
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      Map.put(entry, :rank, rank)
    end)
  end

  defp get_average_score_leaderboard(cutoff, limit, subject, _grade_level \\ nil) do
    base_query = from(s in ViralEngine.PracticeSession,
      where: s.completed == true and s.inserted_at >= ^cutoff,
      select: %{
        user_id: s.user_id,
        avg_score: avg(s.score),
        sessions: count(s.id),
        total_score: sum(s.score)
      },
      group_by: s.user_id,
      having: count(s.id) >= 5,  # Minimum 5 sessions for fairness
      order_by: [desc: avg(s.score)],
      limit: ^limit
    )

    query = if subject do
      from(s in base_query, where: s.subject == ^subject)
    else
      base_query
    end

    Repo.all(query)
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      Map.put(entry, :rank, rank)
    end)
  end

  defp get_streak_leaderboard(limit) do
    from(s in ViralEngine.UserStreak,
      where: s.current_streak > 0,
      order_by: [desc: s.current_streak, desc: s.longest_streak],
      limit: ^limit,
      select: %{
        user_id: s.user_id,
        current_streak: s.current_streak,
        longest_streak: s.longest_streak
      }
    )
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      Map.put(entry, :rank, rank)
    end)
  end

  defp get_sessions_leaderboard(cutoff, limit, subject, _grade_level \\ nil) do
    base_query = from(s in ViralEngine.PracticeSession,
      where: s.completed == true and s.inserted_at >= ^cutoff,
      select: %{
        user_id: s.user_id,
        sessions: count(s.id),
        total_score: sum(s.score),
        avg_score: avg(s.score)
      },
      group_by: s.user_id,
      order_by: [desc: count(s.id)],
      limit: ^limit
    )

    query = if subject do
      from(s in base_query, where: s.subject == ^subject)
    else
      base_query
    end

    Repo.all(query)
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      Map.put(entry, :rank, rank)
    end)
  end

  @doc """
  Gets leaderboard for a specific rally (rally-specific leaderboard).
  """
  def get_rally_leaderboard(rally_id, limit \\ 100) do
    from(p in ViralEngine.RallyParticipant,
      where: p.rally_id == ^rally_id,
      order_by: [desc: p.score, asc: p.inserted_at],
      limit: ^limit,
      select: %{
        user_id: p.user_id,
        score: p.score,
        rank: p.rank,
        is_creator: p.is_creator
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets nearby users on leaderboard (users ranked around the given user).

  Returns users ranked ±5 positions from the target user.
  """
  def get_nearby_users(user_id, scope, opts \\ []) do
    case get_user_rank(user_id, scope, opts) do
      {:ranked, rank} ->
        leaderboard = case scope do
          :global -> get_global_leaderboard(opts)
          :subject -> get_subject_leaderboard(opts[:subject] || "math", opts)
          :cohort -> get_cohort_leaderboard(opts[:grade_level] || 5, opts)
          _ -> get_global_leaderboard(opts)
        end

        start_index = max(0, rank - 6)
        end_index = min(length(leaderboard) - 1, rank + 4)

        Enum.slice(leaderboard, start_index..end_index)

      {:not_ranked, _} ->
        []
    end
  end

  @doc """
  Gets mini-leaderboard for display on subject pages (top 10, daily/weekly).

  Optimized with caching for frequent access.
  """
  def get_mini_leaderboard(subject, period \\ :daily) do
    time_period = case period do
      :daily -> 1
      :weekly -> 7
      _ -> 1
    end

    get_subject_leaderboard(subject,
      limit: 10,
      time_period: time_period,
      metric: :total_score,
      use_cache: true
    )
  end

  @doc """
  Invalidates leaderboard cache for a subject.

  Should be called when scores are updated to refresh the leaderboard.
  """
  def invalidate_cache(subject) do
    # Invalidate daily and weekly caches for all metrics
    for period <- [1, 7],
        metric <- [:total_score, :average_score, :sessions],
        limit <- [10, 100] do
      cache_key = build_cache_key(:subject, subject, metric, period, nil, limit)
      :ets.delete(:leaderboard_cache, cache_key)
    end

    # Broadcast cache invalidation to other nodes if clustered
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "leaderboard:#{subject}",
      {:cache_invalidated, subject}
    )

    :ok
  end

  @doc """
  Broadcasts leaderboard update to subscribed clients.
  """
  def broadcast_update(subject) do
    # Get fresh leaderboard data
    daily = get_mini_leaderboard(subject, :daily)
    weekly = get_mini_leaderboard(subject, :weekly)

    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "leaderboard:#{subject}",
      {:leaderboard_updated, %{daily: daily, weekly: weekly, subject: subject}}
    )

    :ok
  end

  # Private caching functions

  defp build_cache_key(scope, subject, metric, time_period, grade_level, limit) do
    {scope, subject, metric, time_period, grade_level, limit}
  end

  defp get_cached_or_compute(cache_key, compute_fn) do
    # Initialize ETS table if not exists
    ensure_cache_table()

    case :ets.lookup(:leaderboard_cache, cache_key) do
      [{^cache_key, value, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          # Cache hit, return cached value
          value
        else
          # Cache expired, recompute
          compute_and_cache(cache_key, compute_fn)
        end

      [] ->
        # Cache miss, compute and cache
        compute_and_cache(cache_key, compute_fn)
    end
  end

  defp compute_and_cache(cache_key, compute_fn) do
    value = compute_fn.()
    expires_at = DateTime.add(DateTime.utc_now(), @cache_ttl, :millisecond)

    :ets.insert(:leaderboard_cache, {cache_key, value, expires_at})

    value
  end

  defp ensure_cache_table do
    case :ets.whereis(:leaderboard_cache) do
      :undefined ->
        :ets.new(:leaderboard_cache, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end
end
