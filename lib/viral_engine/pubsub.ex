defmodule ViralEngine.PubSub do
  @moduledoc """
  PubSub module for Viral Engine.
  """

  def broadcast_presence_diff(topic, diff) do
    Phoenix.PubSub.broadcast(ViralEngine.PubSub, topic, {:presence_diff, diff})
  end

  def broadcast(topic, event, payload) do
    Phoenix.PubSub.broadcast(ViralEngine.PubSub, topic, {event, payload})
  end
end
