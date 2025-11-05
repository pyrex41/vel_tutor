defmodule ViralEngineWeb.ActivityChannel do
  @moduledoc """
  Channel for real-time activity updates.
  Handles global and subject-specific activity streams.
  """

  use ViralEngineWeb, :channel
  alias ViralEngine.{Activities, PubSubHelper}

  # Use same limit as Activities context for consistency
  @initial_activities_limit 50

  @impl true
  def join("activity:global", _payload, socket) do
    # Authentication check - COPPA/FERPA compliance
    if socket.assigns[:user_id] do
      # Subscribe to activity PubSub topic
      PubSubHelper.subscribe_to_activity()

      # Send recent activities
      recent_activities = Activities.list_recent_activities(limit: @initial_activities_limit)
      {:ok, %{activities: recent_activities}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("activity:subject:" <> subject_id, _payload, socket) do
    # Authentication check - COPPA/FERPA compliance
    if socket.assigns[:user_id] do
      PubSubHelper.subscribe_to_subject_activity(subject_id)

      recent_activities = Activities.list_subject_activities(subject_id, limit: @initial_activities_limit)
      {:ok, %{activities: recent_activities}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:activity, event_type, data}, socket) do
    push(socket, "new_activity", %{
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("react", %{"activity_id" => activity_id, "reaction" => reaction}, socket) do
    user_id = socket.assigns.user_id

    case Activities.add_reaction(activity_id, user_id, reaction) do
      {:ok, _reaction} ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
end
