defmodule ViralEngine.PubSubHelper do
  @moduledoc """
  Helper functions for broadcasting events via PubSub
  """

  alias Phoenix.PubSub

  @pubsub ViralEngine.PubSub

  def broadcast_activity(event_type, data) do
    PubSub.broadcast(@pubsub, "activity:global", {:activity, event_type, data})
  end

  def broadcast_subject_activity(subject_id, event_type, data) do
    PubSub.broadcast(@pubsub, "activity:subject:#{subject_id}", {:activity, event_type, data})
  end

  def broadcast_leaderboard_update(subject_id, data) do
    PubSub.broadcast(@pubsub, "leaderboard:#{subject_id}", {:leaderboard_update, data})
  end

  def subscribe_to_activity do
    PubSub.subscribe(@pubsub, "activity:global")
  end

  def subscribe_to_subject_activity(subject_id) do
    PubSub.subscribe(@pubsub, "activity:subject:#{subject_id}")
  end
end
