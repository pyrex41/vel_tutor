defmodule ViralEngine.AnalyticsContext do
  @moduledoc """
  Simple analytics logging for viral loops.
  """

  alias ViralEngine.{Repo, AnalyticsEvent}
  require Logger

  @doc """
  Log an analytics event for viral loops.
  """
  def log(event_attrs) do
    event = %AnalyticsEvent{
      event_type: event_attrs[:event_type] || "viral_loop",
      user_id: event_attrs[:user_id],
      loop_type: event_attrs[:loop_type],
      action: event_attrs[:action],
      metadata: event_attrs[:metadata] || %{},
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case Repo.insert(event) do
      {:ok, _event} ->
        Logger.debug("Analytics event logged: #{event.event_type} for user #{event.user_id}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to log analytics event: #{inspect(reason)}")
        :error
    end
  end
end