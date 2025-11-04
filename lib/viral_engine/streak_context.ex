defmodule ViralEngine.StreakContext do
  @moduledoc """
  Context module for managing user learning streaks.

  Handles streak tracking, at-risk detection, and rescue invitations.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, UserStreak, PracticeContext}
  require Logger

  @streak_deadline_hours 24  # Streaks break after 24 hours of inactivity

  @doc """
  Gets or creates a user's streak record.
  """
  def get_or_create_streak(user_id) do
    case Repo.get_by(UserStreak, user_id: user_id) do
      nil ->
        %UserStreak{}
        |> UserStreak.changeset(%{
          user_id: user_id,
          current_streak: 0,
          longest_streak: 0,
          last_activity_date: Date.utc_today(),
          next_deadline: calculate_next_deadline(DateTime.utc_now())
        })
        |> Repo.insert()

      streak ->
        {:ok, streak}
    end
  end

  @doc """
  Updates streak after user activity.

  Increments streak if activity is on a new day, resets if streak was broken.
  """
  def record_activity(user_id) do
    {:ok, streak} = get_or_create_streak(user_id)
    today = Date.utc_today()

    cond do
      # Same day activity - no change to streak count
      streak.last_activity_date == today ->
        update_streak(streak, %{
          next_deadline: calculate_next_deadline(DateTime.utc_now()),
          streak_at_risk: false,
          rescue_sent: false
        })

      # Next day activity - increment streak
      Date.diff(today, streak.last_activity_date) == 1 ->
        new_streak = streak.current_streak + 1
        new_longest = max(new_streak, streak.longest_streak)

        update_streak(streak, %{
          current_streak: new_streak,
          longest_streak: new_longest,
          last_activity_date: today,
          next_deadline: calculate_next_deadline(DateTime.utc_now()),
          streak_at_risk: false,
          rescue_sent: false
        })

      # Streak broken - reset to 1
      true ->
        update_streak(streak, %{
          current_streak: 1,
          last_activity_date: today,
          next_deadline: calculate_next_deadline(DateTime.utc_now()),
          streak_at_risk: false,
          rescue_sent: false
        })
    end
  end

  @doc """
  Updates a streak record.
  """
  def update_streak(%UserStreak{} = streak, attrs) do
    streak
    |> UserStreak.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds all at-risk streaks (within 6 hours of breaking).
  """
  def find_at_risk_streaks do
    now = DateTime.utc_now()
    threshold = DateTime.add(now, 6 * 3600, :second)

    from(s in UserStreak,
      where: s.current_streak > 0 and
             s.next_deadline > ^now and
             s.next_deadline <= ^threshold and
             s.rescue_sent == false,
      select: s
    )
    |> Repo.all()
  end

  @doc """
  Finds broken streaks that need to be reset.
  """
  def find_broken_streaks do
    now = DateTime.utc_now()

    from(s in UserStreak,
      where: s.current_streak > 0 and s.next_deadline < ^now,
      select: s
    )
    |> Repo.all()
  end

  @doc """
  Marks a streak as having rescue notification sent.
  """
  def mark_rescue_sent(streak) do
    update_streak(streak, %{
      streak_at_risk: true,
      rescue_sent: true,
      rescue_sent_at: DateTime.utc_now()
    })
  end

  @doc """
  Resets broken streaks.
  """
  def reset_broken_streaks do
    broken = find_broken_streaks()

    Enum.each(broken, fn streak ->
      Logger.info("Resetting broken streak for user #{streak.user_id}")

      update_streak(streak, %{
        current_streak: 0,
        streak_at_risk: false,
        rescue_sent: false
      })
    end)

    length(broken)
  end

  @doc """
  Gets user streak statistics.
  """
  def get_user_stats(user_id) do
    case get_or_create_streak(user_id) do
      {:ok, streak} ->
        hours_remaining = if streak.next_deadline do
          max(0, DateTime.diff(streak.next_deadline, DateTime.utc_now(), :hour))
        else
          0
        end

        %{
          current_streak: streak.current_streak,
          longest_streak: streak.longest_streak,
          hours_remaining: hours_remaining,
          at_risk: UserStreak.at_risk?(streak),
          broken: UserStreak.broken?(streak)
        }

      _ ->
        %{
          current_streak: 0,
          longest_streak: 0,
          hours_remaining: 0,
          at_risk: false,
          broken: false
        }
    end
  end

  # Private functions

  defp calculate_next_deadline(from_datetime) do
    DateTime.add(from_datetime, @streak_deadline_hours * 3600, :second)
  end
end
