defmodule ViralEngine.RallyContext do
  @moduledoc """
  Context module for managing Results Rally viral loops.

  Handles rally creation, participant management, leaderboard updates, and invitations.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, ResultsRally, RallyParticipant, DiagnosticContext}
  require Logger

  @rally_duration_days 7
  @token_salt "results_rally_salt"

  @doc """
  Creates a new results rally from a diagnostic assessment.

  ## Parameters
  - user_id: Creator user ID
  - assessment_id: Diagnostic assessment to base rally on
  - opts: Optional parameters (rally_name, end_date)

  ## Returns
  - {:ok, rally} with generated token
  - {:error, changeset}
  """
  def create_rally(user_id, assessment_id, opts \\ []) do
    assessment = DiagnosticContext.get_assessment(assessment_id)

    if assessment && assessment.user_id == user_id && assessment.completed do
      token = generate_rally_token(user_id, assessment_id)
      start_date = DateTime.utc_now()
      end_date = opts[:end_date] || DateTime.add(start_date, @rally_duration_days * 24 * 3600, :second)

      rally_name = opts[:rally_name] || "#{assessment.subject} Challenge"

      attrs = %{
        creator_id: user_id,
        rally_name: rally_name,
        subject: assessment.subject,
        grade_level: assessment.grade_level,
        rally_token: token,
        start_date: start_date,
        end_date: end_date,
        status: "active",
        participant_count: 1,
        metadata: opts[:metadata] || %{}
      }

      case Repo.transaction(fn ->
        # Create rally
        rally = %ResultsRally{}
        |> ResultsRally.changeset(attrs)
        |> Repo.insert!()

        # Add creator as first participant
        %RallyParticipant{}
        |> RallyParticipant.changeset(%{
          rally_id: rally.id,
          user_id: user_id,
          assessment_id: assessment_id,
          score: assessment.results["overall_score"] || 0,
          rank: 1,
          joined_via: "creator",
          is_creator: true
        })
        |> Repo.insert!()

        rally
      end) do
        {:ok, rally} ->
          # Broadcast rally creation
          broadcast_rally_event(rally, :rally_created)
          {:ok, rally}

        {:error, _changeset} = error ->
          error
      end
    else
      {:error, :invalid_assessment}
    end
  end

  @doc """
  Generates a signed rally token.
  """
  def generate_rally_token(user_id, assessment_id) do
    data = "#{user_id}:#{assessment_id}:#{System.system_time(:second)}"
    :crypto.hash(:sha256, data <> @token_salt)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 32)
  end

  @doc """
  Gets a rally by token.
  """
  def get_rally_by_token(token) do
    from(r in ResultsRally,
      where: r.rally_token == ^token
    )
    |> Repo.one()
  end

  @doc """
  Gets a rally by ID.
  """
  def get_rally(id) do
    Repo.get(ResultsRally, id)
  end

  @doc """
  Joins a rally.

  ## Parameters
  - token: Rally token from invite link
  - user_id: User joining the rally
  - assessment_id: User's completed assessment

  ## Returns
  - {:ok, participant} - Successfully joined
  - {:error, reason} - Failed to join
  """
  def join_rally(token, user_id, assessment_id) do
    rally = get_rally_by_token(token)
    assessment = DiagnosticContext.get_assessment(assessment_id)

    cond do
      is_nil(rally) ->
        {:error, :rally_not_found}

      !ResultsRally.active?(rally) ->
        {:error, :rally_ended}

      is_nil(assessment) || !assessment.completed ->
        {:error, :invalid_assessment}

      assessment.subject != rally.subject ->
        {:error, :subject_mismatch}

      already_in_rally?(rally.id, user_id) ->
        {:error, :already_joined}

      true ->
        # Add participant
        participant = %RallyParticipant{}
        |> RallyParticipant.changeset(%{
          rally_id: rally.id,
          user_id: user_id,
          assessment_id: assessment_id,
          score: assessment.results["overall_score"] || 0,
          joined_via: "invite_link",
          is_creator: false
        })
        |> Repo.insert()

        case participant do
          {:ok, p} ->
            # Update rally participant count
            update_rally(rally, %{
              participant_count: rally.participant_count + 1,
              invite_count: rally.invite_count + 1
            })

            # Update ranks for all participants
            update_rally_ranks(rally.id)

            # Broadcast participant joined
            broadcast_rally_event(rally, :participant_joined, %{user_id: user_id})

            {:ok, p}

          error ->
            error
        end
    end
  end

  @doc """
  Gets leaderboard for a rally with real-time rankings.

  ## Options
  - limit: Max participants to return (default 100)
  - user_id: Highlight specific user in results
  """
  def get_rally_leaderboard(rally_id, opts \\ []) do
    limit = opts[:limit] || 100
    user_id = opts[:user_id]

    participants = from(p in RallyParticipant,
      where: p.rally_id == ^rally_id,
      order_by: [desc: p.score, asc: p.inserted_at],
      limit: ^limit,
      select: %{
        user_id: p.user_id,
        score: p.score,
        rank: p.rank,
        is_creator: p.is_creator,
        joined_at: p.inserted_at
      }
    )
    |> Repo.all()

    # Calculate percentile for user if specified
    user_percentile = if user_id do
      calculate_percentile(rally_id, user_id)
    else
      nil
    end

    %{
      participants: participants,
      total_count: length(participants),
      user_percentile: user_percentile
    }
  end

  @doc """
  Updates a rally.
  """
  def update_rally(%ResultsRally{} = rally, attrs) do
    rally
    |> ResultsRally.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists rallies for a user (created or participated).
  """
  def list_user_rallies(user_id, opts \\ []) do
    limit = opts[:limit] || 20
    status = opts[:status]

    participant_rally_ids = from(p in RallyParticipant,
      where: p.user_id == ^user_id,
      select: p.rally_id
    )
    |> Repo.all()

    base_query = from(r in ResultsRally,
      where: r.id in ^participant_rally_ids,
      order_by: [desc: r.inserted_at],
      limit: ^limit
    )

    query = if status do
      from(r in base_query, where: r.status == ^status)
    else
      base_query
    end

    Repo.all(query)
  end

  @doc """
  Gets rally statistics for a user.
  """
  def get_user_rally_stats(user_id) do
    participant_data = from(p in RallyParticipant,
      where: p.user_id == ^user_id,
      select: %{
        total: count(p.id),
        first_place: sum(fragment("CASE WHEN ? = 1 THEN 1 ELSE 0 END", p.rank)),
        top_three: sum(fragment("CASE WHEN ? <= 3 THEN 1 ELSE 0 END", p.rank)),
        created: sum(fragment("CASE WHEN ? = true THEN 1 ELSE 0 END", p.is_creator)),
        avg_score: avg(p.score)
      }
    )
    |> Repo.one()

    if participant_data do
      %{
        total_rallies: participant_data.total,
        first_place_finishes: participant_data.first_place || 0,
        top_three_finishes: participant_data.top_three || 0,
        rallies_created: participant_data.created || 0,
        average_score: if(participant_data.avg_score, do: Float.round(participant_data.avg_score, 2), else: 0.0)
      }
    else
      %{
        total_rallies: 0,
        first_place_finishes: 0,
        top_three_finishes: 0,
        rallies_created: 0,
        average_score: 0.0
      }
    end
  end

  @doc """
  Generates a deep link URL for a rally.
  """
  def generate_rally_link(rally) do
    base_url = Application.get_env(:viral_engine, :base_url, "https://app.veltutor.com")
    "#{base_url}/rally/#{rally.rally_token}"
  end

  @doc """
  Generates a shareable message for a rally.
  """
  def generate_share_message(rally) do
    """
    Join my #{rally.subject} leaderboard challenge! 🏆

    Compete with me and others to see who scores highest.

    Join here: #{generate_rally_link(rally)}

    Let's rally together! 🎯
    """
  end

  @doc """
  Ends expired rallies (cleanup job).
  """
  def end_expired_rallies do
    now = DateTime.utc_now()

    from(r in ResultsRally,
      where: r.status == "active" and r.end_date < ^now
    )
    |> Repo.update_all(set: [status: "ended"])
  end

  # Private functions

  defp already_in_rally?(rally_id, user_id) do
    Repo.exists?(
      from(p in RallyParticipant,
        where: p.rally_id == ^rally_id and p.user_id == ^user_id
      )
    )
  end

  defp update_rally_ranks(rally_id) do
    # Get all participants ordered by score
    participants = from(p in RallyParticipant,
      where: p.rally_id == ^rally_id,
      order_by: [desc: p.score, asc: p.inserted_at],
      select: p
    )
    |> Repo.all()

    # Update ranks
    participants
    |> Enum.with_index(1)
    |> Enum.each(fn {participant, rank} ->
      from(p in RallyParticipant, where: p.id == ^participant.id)
      |> Repo.update_all(set: [rank: rank])
    end)

    # Broadcast rank updates
    rally = get_rally(rally_id)
    broadcast_rally_event(rally, :ranks_updated)
  end

  defp calculate_percentile(rally_id, user_id) do
    # Get user's rank
    user_participant = from(p in RallyParticipant,
      where: p.rally_id == ^rally_id and p.user_id == ^user_id,
      select: p
    )
    |> Repo.one()

    if user_participant do
      # Get total participants
      total = from(p in RallyParticipant,
        where: p.rally_id == ^rally_id,
        select: count(p.id)
      )
      |> Repo.one()

      percentile = (total - user_participant.rank) / total * 100
      Float.round(percentile, 1)
    else
      nil
    end
  end

  defp broadcast_rally_event(rally, event_type, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "rally:#{rally.id}",
      {event_type, Map.merge(data, %{rally_id: rally.id})}
    )
  end
end
