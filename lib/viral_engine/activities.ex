defmodule ViralEngine.Activities do
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.Activities.{Event, Reaction}
  alias ViralEngine.PubSubHelper

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

  def list_recent_activities(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in Event,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def list_subject_activities(subject_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in Event,
      where: e.subject_id == ^subject_id,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
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
    # Check user's privacy settings
    # For now, return false (everyone participates by default)
    # In production, this would check user preferences in the database
    # user = Repo.get(User, user_id)
    # user.activity_opt_out or false
    false
  end
end
