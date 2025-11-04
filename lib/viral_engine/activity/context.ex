defmodule ViralEngine.Activity.Context do
  alias ViralEngine.Repo
  alias ViralEngine.Activity.Activity

  def create_activity(attrs) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
    |> broadcast_activity()
  end

  def list_activities_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    type_filter = Keyword.get(opts, :type, nil)

    query =
      from(a in Activity,
        where: a.user_id == ^user_id or is_nil(a.target_id) or a.target_id == ^user_id,
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user]
      )

    query = if type_filter, do: from(a in query, where: a.type == ^type_filter), else: query
    Repo.all(query)
  end

  def toggle_like(activity_id, user_id) do
    activity = Repo.get!(Activity, activity_id)

    case activity.type do
      "like" ->
        # Remove like
        Repo.delete!(activity)
        {:ok, :unliked}

      _ ->
        # Add like
        like_attrs = %{
          type: "like",
          content: "liked an activity",
          user_id: user_id,
          target_id: activity_id,
          target_type: activity.type
        }

        create_activity(like_attrs)
    end
  end

  def list_activities_paginated(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor = Keyword.get(opts, :cursor, nil)
    type_filter = Keyword.get(opts, :type, nil)

    query =
      from(a in Activity,
        where: a.user_id == ^user_id or is_nil(a.target_id) or a.target_id == ^user_id,
        order_by: [desc: a.inserted_at],
        limit: ^limit + 1,
        preload: [:user]
      )

    query = if type_filter, do: from(a in query, where: a.type == ^type_filter), else: query
    query = if cursor, do: from(a in query, where: a.inserted_at < ^cursor), else: query

    results = Repo.all(query)

    {Enum.slice(results, 0, limit),
     List.last(results) && results |> List.last() |> Map.get(:inserted_at)}
  end

  def toggle_like(activity_id, user_id) do
    activity = Repo.get!(Activity, activity_id)

    case activity.type do
      "like" ->
        # Remove like
        Repo.delete!(activity)
        {:ok, :unliked}

      _ ->
        # Add like
        like_attrs = %{
          type: "like",
          content: "liked an activity",
          user_id: user_id,
          target_id: activity_id,
          target_type: activity.type
        }

        create_activity(like_attrs)
    end
  end

  defp broadcast_activity({:ok, activity}) do
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "activities:#{activity.user_id}",
      {:activity, activity.user_id, activity}
    )

    {:ok, activity}
  end

  defp broadcast_activity({:error, _} = error), do: error
end
