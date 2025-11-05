defmodule ViralEngineWeb.Live.ViralPromptsHook do
  @moduledoc """
  LiveView on_mount hook for viral prompt integration.

  Handles:
  - Subscribing to viral loop events
  - Throttling prompt display
  - A/B test variant assignment
  - Experiment exposure logging
  - Fallback to default prompts

  Usage:
    defmodule MyLive do
      use ViralEngineWeb, :live_view

      on_mount ViralEngineWeb.Live.ViralPromptsHook
    end
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 2, assign: 3]
  alias ViralEngine.{LoopOrchestrator, ExperimentContext}
  require Logger

  # Active experiments for viral loops
  @active_experiments %{
    "buddy_challenge" => "buddy_challenge_cta_v1",
    "results_rally" => "results_rally_cta_v1",
    "streak_rescue" => "streak_rescue_cta_v1",
    "proud_parent" => "proud_parent_cta_v1"
  }

  def on_mount(:default, _params, _session, socket) do
    # Get user_id from socket assigns (assuming it's set by auth)
    user_id = get_user_id(socket)

    if connected?(socket) && user_id do
      # Subscribe to viral events for this user
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user_id}:viral")

      # Check if user is currently throttled
      {:ok, throttled} = LoopOrchestrator.check_throttle(user_id)

      # Get experiment variants for all active viral loops
      variants = get_experiment_variants(user_id)

      socket =
        socket
        |> assign(:viral_prompts_enabled, true)
        |> assign(:viral_throttled, throttled)
        |> assign(:viral_prompt, nil)
        |> assign(:viral_variant_cache, variants)

      {:cont, socket}
    else
      {:cont, assign(socket, viral_prompts_enabled: false)}
    end
  end

  @doc """
  Gets experiment variants for all active viral loops.
  Returns a map of loop_type => variant.
  """
  def get_experiment_variants(user_id) do
    Enum.reduce(@active_experiments, %{}, fn {loop_type, experiment_key}, acc ->
      case ExperimentContext.get_or_assign(experiment_key, user_id) do
        {:ok, variant} ->
          Map.put(acc, loop_type, variant)

        {:default, variant} ->
          Map.put(acc, loop_type, variant)

        {:error, _} ->
          Map.put(acc, loop_type, "control")
      end
    end)
  end

  @doc """
  Logs exposure when a viral prompt variant is displayed.
  Call this when the prompt is actually shown to the user.

  ## Example
      def handle_info({:viral_prompt, prompt_data}, socket) do
        # Show the prompt
        socket = assign(socket, :viral_prompt, prompt_data)

        # Log exposure for experiment
        log_variant_exposure(socket, prompt_data.loop_type)

        {:noreply, socket}
      end
  """
  def log_variant_exposure(socket, loop_type) do
    user_id = get_user_id(socket)
    variant = get_in(socket.assigns, [:viral_variant_cache, loop_type])
    experiment_key = @active_experiments[loop_type]

    if user_id && variant && experiment_key do
      case ExperimentContext.log_exposure(experiment_key, user_id, variant) do
        {:ok, _} ->
          Logger.debug("Logged exposure: experiment=#{experiment_key}, user=#{user_id}, variant=#{variant}")
          :ok

        {:error, reason} ->
          Logger.warning("Failed to log exposure: #{inspect(reason)}")
          :error
      end
    else
      Logger.debug("Skipped exposure logging: missing user_id, variant, or experiment_key")
      :ok
    end
  end

  @doc """
  Gets the variant for a specific loop type from the cache.
  Returns "control" as default if not found.
  """
  def get_variant(socket, loop_type) do
    get_in(socket.assigns, [:viral_variant_cache, loop_type]) || "control"
  end

  defp get_user_id(socket) do
    # Try to get user_id from various possible assigns
    socket.assigns[:user_id] ||
    socket.assigns[:current_user_id] ||
    socket.assigns[:current_user][:id] ||
    nil
  end
end
