defmodule ViralEngine.Activities do
  @moduledoc """
  Context module for managing activity events and reactions in the viral engine.
  Handles creation, retrieval, and broadcasting of user activities.
  """

  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.Activities.{Event, Reaction}
  alias ViralEngine.PubSubHelper

  # Pagination constants
  @default_activity_limit 50
  @max_activity_limit 100

  def create_event(attrs) do
    with {:ok, event} <- %Event{} |> Event.changeset(attrs) |> Repo.insert() do
      # Only broadcast public events from users who haven't opted out
      if event.visibility == "public" and not user_opted_out?(event.user_id) do
        PubSubHelper.broadcast_activity(event.event_type, event)

        if event.subject_id do
          PubSubHelper.broadcast_subject_activity(event.subject_id, event.event_type, event)
        end
      end

      {:ok, event}
    end
  end

  @doc """
  Lists recent activities with pagination support.

  ## Options
    * `:limit` - Maximum number of activities to return (default: #{@default_activity_limit}, max: #{@max_activity_limit})
    * `:offset` - Number of activities to skip for pagination (default: 0)

  ## Examples
      iex> list_recent_activities(limit: 20, offset: 0)
      iex> list_recent_activities(limit: 20, offset: 20)  # Page 2
  """
  def list_recent_activities(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_activity_limit) |> min(@max_activity_limit)
    offset = Keyword.get(opts, :offset, 0)

    from(e in Event,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Lists activities for a specific subject with pagination support.

  ## Options
    * `:limit` - Maximum number of activities to return (default: #{@default_activity_limit}, max: #{@max_activity_limit})
    * `:offset` - Number of activities to skip for pagination (default: 0)
  """
  def list_subject_activities(subject_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_activity_limit) |> min(@max_activity_limit)
    offset = Keyword.get(opts, :offset, 0)

    from(e in Event,
      where: e.subject_id == ^subject_id,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:user]
    )
    |> Repo.all()
  end

  def add_reaction(activity_id, user_id, reaction) do
    %Reaction{}
    |> Reaction.changeset(%{
      activity_event_id: activity_id,
      user_id: user_id,
      reaction: reaction
    })
    |> Repo.insert()
    |> case do
      {:ok, reaction} ->
        increment_reactions_count(activity_id)
        {:ok, reaction}

      error ->
        error
    end
  end

  defp increment_reactions_count(activity_id) do
    from(e in Event, where: e.id == ^activity_id)
    |> Repo.update_all(inc: [reactions_count: 1])
  end

  # Check if user has opted out of activity sharing
  defp user_opted_out?(user_id) do
    # Check user's privacy settings for COPPA/FERPA compliance
    case Repo.get(ViralEngine.Accounts.User, user_id) do
      nil -> true  # User not found, opt out by default for safety
      user -> user.activity_opt_out || false
    end
  end
end
