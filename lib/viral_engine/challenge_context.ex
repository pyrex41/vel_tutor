defmodule ViralEngine.ChallengeContext do
  @moduledoc """
  Context module for managing buddy challenges.

  Handles challenge creation, token generation, acceptance, and completion.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, BuddyChallenge, PracticeContext}
  require Logger

  @challenge_expiry_days 7
  @token_salt "buddy_challenge_salt"

  @doc """
  Creates a new buddy challenge from a practice session.

  ## Parameters
  - challenger_id: User creating the challenge
  - session_id: Practice session to challenge on
  - opts: Optional parameters (challenged_user_id, challenged_email, share_method)

  ## Returns
  - {:ok, challenge} with generated token
  - {:error, changeset}
  """
  def create_challenge(challenger_id, session_id, opts \\ []) do
    # Get session details
    session = PracticeContext.get_session(session_id)

    if session && session.user_id == challenger_id && session.completed do
      # Generate signed token
      token = generate_challenge_token(challenger_id, session_id)
      expires_at = DateTime.utc_now() |> DateTime.add(@challenge_expiry_days * 24 * 3600, :second)

      attrs = %{
        challenger_id: challenger_id,
        challenged_user_id: opts[:challenged_user_id],
        challenged_email: opts[:challenged_email],
        session_id: session_id,
        subject: session.subject,
        challenger_score: session.score || 0,
        challenge_token: token,
        status: "pending",
        expires_at: expires_at,
        share_method: opts[:share_method] || "link",
        metadata: opts[:metadata] || %{}
      }

      %BuddyChallenge{}
      |> BuddyChallenge.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :invalid_session}
    end
  end

  @doc """
  Generates a signed challenge token.
  """
  def generate_challenge_token(challenger_id, session_id) do
    data = "#{challenger_id}:#{session_id}:#{System.system_time(:second)}"
    :crypto.hash(:sha256, data <> @token_salt)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 32)
  end

  @doc """
  Gets a challenge by token.
  """
  def get_challenge_by_token(token) do
    from(c in BuddyChallenge,
      where: c.challenge_token == ^token
    )
    |> Repo.one()
  end

  @doc """
  Gets a challenge by ID.
  """
  def get_challenge(id) do
    Repo.get(BuddyChallenge, id)
  end

  @doc """
  Accepts a buddy challenge.

  ## Parameters
  - token: Challenge token from deep link
  - user_id: User accepting the challenge

  ## Returns
  - {:ok, challenge} - Challenge accepted
  - {:error, :not_found} - Challenge not found
  - {:error, :expired} - Challenge has expired
  - {:error, :already_accepted} - Challenge already accepted
  - {:error, :self_challenge} - User trying to accept their own challenge
  """
  def accept_challenge(token, user_id) do
    case get_challenge_by_token(token) do
      nil ->
        {:error, :not_found}

      challenge ->
        cond do
          BuddyChallenge.expired?(challenge) ->
            update_challenge(challenge, %{status: "expired"})
            {:error, :expired}

          challenge.challenger_id == user_id ->
            {:error, :self_challenge}

          challenge.status != "pending" ->
            {:error, :already_accepted}

          true ->
            update_challenge(challenge, %{
              challenged_user_id: user_id,
              status: "accepted",
              accepted_at: DateTime.utc_now()
            })
        end
    end
  end

  @doc """
  Completes a challenge after the challenged user finishes the session.

  ## Parameters
  - challenge_id: Challenge ID
  - challenged_session_id: Session completed by challenged user

  ## Returns
  - {:ok, challenge} with winner determined and rewards granted
  - {:error, reason}
  """
  def complete_challenge(challenge_id, challenged_session_id) do
    challenge = get_challenge(challenge_id)
    session = PracticeContext.get_session(challenged_session_id)

    if challenge && session && session.completed do
      winner_id = if session.score > challenge.challenger_score do
        challenge.challenged_user_id
      else
        challenge.challenger_id
      end

      {:ok, updated_challenge} = update_challenge(challenge, %{
        challenged_score: session.score,
        status: "completed",
        completed_at: DateTime.utc_now(),
        winner_id: winner_id
      })

      # Grant rewards
      grant_challenge_rewards(updated_challenge)

      # Broadcast completion
      broadcast_challenge_completion(updated_challenge)

      {:ok, updated_challenge}
    else
      {:error, :invalid_completion}
    end
  end

  @doc """
  Updates a challenge.
  """
  def update_challenge(%BuddyChallenge{} = challenge, attrs) do
    challenge
    |> BuddyChallenge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists challenges for a user (both as challenger and challenged).

  ## Options
  - status: Filter by status
  - limit: Max results (default 20)
  """
  def list_user_challenges(user_id, opts \\ []) do
    limit = opts[:limit] || 20
    status = opts[:status]

    base_query = from(c in BuddyChallenge,
      where: c.challenger_id == ^user_id or c.challenged_user_id == ^user_id,
      order_by: [desc: c.inserted_at],
      limit: ^limit
    )

    query = if status do
      from(c in base_query, where: c.status == ^status)
    else
      base_query
    end

    Repo.all(query)
  end

  @doc """
  Gets challenge statistics for a user.
  """
  def get_user_challenge_stats(user_id) do
    stats = from(c in BuddyChallenge,
      where: c.challenger_id == ^user_id or c.challenged_user_id == ^user_id,
      select: %{
        total: count(c.id),
        completed: sum(fragment("CASE WHEN ? = 'completed' THEN 1 ELSE 0 END", c.status)),
        won: sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", c.winner_id, ^user_id)),
        created: sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", c.challenger_id, ^user_id)),
        accepted: sum(fragment("CASE WHEN ? = ? AND ? = 'completed' THEN 1 ELSE 0 END", c.challenged_user_id, ^user_id, c.status))
      }
    )
    |> Repo.one()

    if stats do
      win_rate = if stats.completed > 0, do: (stats.won || 0) / stats.completed * 100, else: 0.0

      %{
        total_challenges: stats.total,
        completed_challenges: stats.completed || 0,
        challenges_won: stats.won || 0,
        challenges_created: stats.created || 0,
        challenges_accepted: stats.accepted || 0,
        win_rate: Float.round(win_rate, 2)
      }
    else
      %{
        total_challenges: 0,
        completed_challenges: 0,
        challenges_won: 0,
        challenges_created: 0,
        challenges_accepted: 0,
        win_rate: 0.0
      }
    end
  end

  @doc """
  Generates a deep link URL for a challenge.
  """
  def generate_challenge_link(challenge) do
    base_url = Application.get_env(:viral_engine, :base_url, "https://app.veltutor.com")
    "#{base_url}/challenge/#{challenge.challenge_token}"
  end

  @doc """
  Generates a shareable message for a challenge.
  """
  def generate_share_message(challenge) do
    """
    I just scored #{challenge.challenger_score}% on #{challenge.subject}! Think you can beat me?

    Accept my challenge: #{generate_challenge_link(challenge)}

    Let's see who's smarter! 🎯
    """
  end

  # Private functions

  defp grant_challenge_rewards(%BuddyChallenge{reward_granted: true}), do: :ok
  defp grant_challenge_rewards(challenge) do
    # Grant XP/rewards to both users
    Task.start(fn ->
      # Winner gets 50 XP, challenger gets 25 XP for creating challenge
      winner_xp = 50
      creator_xp = 25

      Logger.info("Granting #{winner_xp} XP to winner #{challenge.winner_id}")
      Logger.info("Granting #{creator_xp} XP to challenger #{challenge.challenger_id}")

      # In production, would call RewardsContext.grant_xp/2
      # RewardsContext.grant_xp(challenge.winner_id, winner_xp)
      # RewardsContext.grant_xp(challenge.challenger_id, creator_xp)

      # Mark rewards as granted
      update_challenge(challenge, %{reward_granted: true})
    end)
  end

  defp broadcast_challenge_completion(challenge) do
    # Broadcast to both users
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "user:#{challenge.challenger_id}:challenges",
      {:challenge_completed, challenge}
    )

    if challenge.challenged_user_id do
      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "user:#{challenge.challenged_user_id}:challenges",
        {:challenge_completed, challenge}
      )
    end
  end

  @doc """
  Expires old pending challenges (cleanup job).
  """
  def expire_old_challenges do
    now = DateTime.utc_now()

    from(c in BuddyChallenge,
      where: c.status == "pending" and c.expires_at < ^now
    )
    |> Repo.update_all(set: [status: "expired"])
  end
end
