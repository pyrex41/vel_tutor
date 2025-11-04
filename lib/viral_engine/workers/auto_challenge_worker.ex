defmodule ViralEngine.Workers.AutoChallengeWorker do
  @moduledoc """
  Oban worker that automatically creates "Beat My Skill" challenges
  when users show session gaps.

  Agentic Action: Detects inactivity and triggers re-engagement via challenges.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3

  alias ViralEngine.{ChallengeContext, ViralPrompts}
  require Logger

  @session_gap_days 3  # Trigger if no practice for 3+ days
  @lookback_days 30    # Look back 30 days for best score

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("AutoChallengeWorker: Checking for users with session gaps")

    # Find users who haven't practiced in X days
    inactive_users = find_inactive_users(@session_gap_days)

    Logger.info("Found #{length(inactive_users)} inactive users")

    # Generate challenges for each inactive user
    Enum.each(inactive_users, fn user_id ->
      case generate_auto_challenge(user_id) do
        {:ok, challenge} ->
          Logger.info("Auto-challenge created for user #{user_id}: #{challenge.challenge_token}")

          # Trigger viral prompt to share the challenge
          trigger_challenge_prompt(user_id, challenge)

        {:skip, reason} ->
          Logger.debug("Skipped auto-challenge for user #{user_id}: #{reason}")

        {:error, reason} ->
          Logger.error("Failed to create auto-challenge for user #{user_id}: #{inspect(reason)}")
      end
    end)

    :ok
  end

  @doc """
  Finds users who haven't practiced in the specified number of days.
  """
  def find_inactive_users(days) do
    _cutoff_date = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Query users with last practice session before cutoff
    # This would need a proper query against the practice_sessions table
    # For now, simulate with sample data

    # In production:
    # from(ps in PracticeSession,
    #   where: ps.completed_at < ^cutoff_date,
    #   group_by: ps.user_id,
    #   having: max(ps.completed_at) < ^cutoff_date,
    #   select: ps.user_id
    # )
    # |> Repo.all()

    # Simulated: Return empty list (no inactive users in development)
    []
  end

  @doc """
  Generates an automatic "Beat My Skill" challenge for a user.

  Creates a challenge based on their best past performance.
  """
  def generate_auto_challenge(user_id) do
    # Get user's best session from the past 30 days
    case find_best_recent_session(user_id, @lookback_days) do
      nil ->
        {:skip, :no_recent_sessions}

      best_session ->
        # Check if user already has an active auto-challenge
        if has_active_auto_challenge?(user_id) do
          {:skip, :already_has_challenge}
        else
          # Create self-challenge to beat their own score
          metadata = %{
            auto_generated: true,
            original_session_id: best_session.id,
            gap_days: @session_gap_days,
            challenge_type: "beat_my_skill",
            message: "Can you beat your best score of #{best_session.score}?"
          }

          case ChallengeContext.create_challenge(user_id, best_session.id, challenged_user_id: user_id, metadata: metadata) do
            {:ok, challenge} ->
              # Mark as auto-generated in metadata
              {:ok, challenge}

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  @doc """
  Finds the user's best scoring session in the past N days.
  """
  def find_best_recent_session(_user_id, lookback_days) do
    _cutoff_date = DateTime.add(DateTime.utc_now(), -lookback_days * 24 * 60 * 60, :second)

    # Query best session by score
    # In production:
    # from(ps in PracticeSession,
    #   where: ps.user_id == ^user_id and
    #          ps.completed_at > ^cutoff_date and
    #          ps.completed == true,
    #   order_by: [desc: ps.score],
    #   limit: 1
    # )
    # |> Repo.one()

    # Simulated: No session
    nil
  end

  @doc """
  Checks if user already has an active auto-generated challenge.
  """
  def has_active_auto_challenge?(_user_id) do
    # Query for active auto-challenges
    # In production:
    # from(c in Challenge,
    #   where: c.challenger_id == ^user_id and
    #          c.status == "pending" and
    #          fragment("?->>'auto_generated' = 'true'", c.metadata)
    # )
    # |> Repo.exists?()

    # Simulated: No active challenges
    false
  end

  # Triggers a viral prompt to encourage the user to share their challenge.
  defp trigger_challenge_prompt(user_id, challenge) do
    event_data = %{
      challenge_id: challenge.id,
      challenge_token: challenge.challenge_token,
      challenge_type: "beat_my_skill",
      target_score: challenge.target_score,
      subject: challenge.subject
    }

    case ViralPrompts.trigger_prompt(:auto_challenge_created, user_id, event_data) do
      {:ok, _prompt} ->
        Logger.info("Triggered auto-challenge prompt for user #{user_id}")
        ViralPrompts.broadcast_event(:auto_challenge_created, user_id, event_data)

      {:throttled, reason} ->
        Logger.debug("Auto-challenge prompt throttled for user #{user_id}: #{reason}")

      {:no_prompt, reason} ->
        Logger.debug("No auto-challenge prompt for user #{user_id}: #{reason}")
    end
  end

  @doc """
  Enqueues the worker to run periodically (daily at 9 AM).
  """
  def schedule_daily do
    # Schedule to run every day at 9 AM
    %{}
    |> __MODULE__.new(schedule: "0 9 * * *")
    |> Oban.insert()
  end
end
