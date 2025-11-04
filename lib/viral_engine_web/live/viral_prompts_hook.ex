defmodule ViralEngineWeb.Live.ViralPromptsHook do
  @moduledoc """
  LiveView on_mount hook for viral prompt integration.

  Handles:
  - Subscribing to viral loop events
  - Throttling prompt display
  - A/B test variant assignment
  - Fallback to default prompts

  Usage:
    defmodule MyLive do
      use ViralEngineWeb, :live_view

      on_mount ViralEngineWeb.Live.ViralPromptsHook
    end
  """

  import Phoenix.LiveView
  alias ViralEngine.LoopOrchestrator

  def on_mount(:default, _params, _session, socket) do
    # Get user_id from socket assigns (assuming it's set by auth)
    user_id = get_user_id(socket)

    if connected?(socket) && user_id do
      # Subscribe to viral events for this user
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user_id}:viral")

      # Check if user is currently throttled
      {:ok, throttled} = LoopOrchestrator.check_throttle(user_id)

      socket =
        socket
        |> assign(:viral_prompts_enabled, true)
        |> assign(:viral_throttled, throttled)
        |> assign(:viral_prompt, nil)
        |> assign(:viral_variant_cache, %{})

      {:cont, socket}
    else
      {:cont, assign(socket, viral_prompts_enabled: false)}
    end
  end

  defp get_user_id(socket) do
    # Try to get user_id from various possible assigns
    socket.assigns[:user_id] ||
    socket.assigns[:current_user_id] ||
    socket.assigns[:current_user][:id] ||
    nil
  end
end
