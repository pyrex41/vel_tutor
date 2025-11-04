defmodule ViralEngine.Workers.StreakRescueWorker do
  @moduledoc """
  Oban worker for detecting at-risk streaks and triggering rescue notifications.

  Runs every hour to check for streaks that are within 6 hours of breaking.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  alias ViralEngine.{StreakContext, ViralPrompts}
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Running streak rescue check...")

    # Find at-risk streaks
    at_risk_streaks = StreakContext.find_at_risk_streaks()

    Logger.info("Found #{length(at_risk_streaks)} at-risk streaks")

    # Trigger rescue loop for each at-risk user
    Enum.each(at_risk_streaks, fn streak ->
      trigger_rescue_loop(streak)
    end)

    # Reset broken streaks
    broken_count = StreakContext.reset_broken_streaks()
    Logger.info("Reset #{broken_count} broken streaks")

    {:ok, %{at_risk: length(at_risk_streaks), reset: broken_count}}
  end

  defp trigger_rescue_loop(streak) do
    hours_remaining = DateTime.diff(streak.next_deadline, DateTime.utc_now(), :hour)

    event_data = %{
      current_streak: streak.current_streak,
      hours_remaining: hours_remaining,
      streak_id: streak.id
    }

    # Trigger viral prompt for streak rescue
    case ViralPrompts.trigger_prompt(:streak_at_risk, streak.user_id, event_data) do
      {:ok, _prompt} ->
        Logger.info("Streak rescue triggered for user #{streak.user_id}")

        # Mark as rescue sent
        StreakContext.mark_rescue_sent(streak)

        # Broadcast event
        ViralPrompts.broadcast_event(:streak_at_risk, streak.user_id, event_data)

      {:throttled, reason} ->
        Logger.info("Streak rescue throttled for user #{streak.user_id}: #{reason}")

      {:no_prompt, reason} ->
        Logger.info("No streak rescue prompt for user #{streak.user_id}: #{reason}")
    end
  end
end
