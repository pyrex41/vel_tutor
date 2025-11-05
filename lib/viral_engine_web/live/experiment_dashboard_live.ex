defmodule ViralEngineWeb.ExperimentDashboardLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ExperimentContext, Repo, Experiment}
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Require admin role
    unless user.role == "admin" do
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: "/dashboard")}
    else
      socket = if connected?(socket) do
        # Refresh every 30 seconds
        {:ok, timer_ref} = :timer.send_interval(30_000, self(), :refresh_experiments)
        assign(socket, :timer_ref, timer_ref)
      else
        socket
      end

      experiments = list_experiments()

      {:ok,
       socket
       |> assign(:user, user)
       |> assign(:experiments, experiments)
       |> assign(:show_form, false)
       |> assign(:form_experiment, nil)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    # Clean up timer to prevent memory leaks
    if timer_ref = socket.assigns[:timer_ref] do
      :timer.cancel(timer_ref)
    end
    :ok
  end

  @impl true
  def handle_event("show_create_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, form_experiment: nil)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_experiment: nil)}
  end

  @impl true
  def handle_event("create_experiment", params, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      experiment_key: params["experiment_key"],
      variants: parse_variants(params["variants"]),
      target_metric: params["target_metric"],
      status: "draft",
      traffic_allocation: String.to_integer(params["traffic_allocation"] || "100")
    }

    case %Experiment{}
         |> Experiment.changeset(attrs)
         |> Repo.insert() do
      {:ok, _experiment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Experiment created successfully")
         |> assign(:show_form, false)
         |> update(:experiments, fn _ -> list_experiments() end)}

      {:error, changeset} ->
        Logger.error("Failed to create experiment: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to create experiment")}
    end
  end

  @impl true
  def handle_event("start_experiment", %{"id" => id}, socket) do
    case ExperimentContext.start_experiment(String.to_integer(id)) do
      {:ok, _experiment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Experiment started")
         |> update(:experiments, fn _ -> list_experiments() end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start experiment")}
    end
  end

  @impl true
  def handle_event("stop_experiment", %{"id" => id}, socket) do
    case ExperimentContext.stop_experiment(String.to_integer(id)) do
      {:ok, _experiment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Experiment stopped")
         |> update(:experiments, fn _ -> list_experiments() end)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to stop experiment")}
    end
  end

  @impl true
  def handle_event("view_results", %{"id" => id}, socket) do
    experiment_id = String.to_integer(id)
    results = ExperimentContext.get_experiment_results(experiment_id)

    {:noreply,
     socket
     |> assign(:viewing_results, experiment_id)
     |> assign(:results, results)}
  end

  @impl true
  def handle_event("declare_winner", %{"id" => id, "variant" => variant}, socket) do
    case ExperimentContext.declare_winner(String.to_integer(id), variant) do
      {:ok, _experiment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Winner declared: #{variant}")
         |> update(:experiments, fn _ -> list_experiments() end)
         |> assign(:viewing_results, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to declare winner")}
    end
  end

  @impl true
  def handle_info(:refresh_experiments, socket) do
    {:noreply, update(socket, :experiments, fn _ -> list_experiments() end)}
  end

  defp list_experiments do
    Repo.all(Experiment)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp parse_variants(variants_str) do
    # Expected format: "control:50,variant_a:50"
    variants_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reduce(%{}, fn variant_weight, acc ->
      case String.split(variant_weight, ":") do
        [variant, weight] ->
          Map.put(acc, variant, %{"weight" => String.to_integer(weight)})

        _ ->
          acc
      end
    end)
  end

  # Helper functions
  defp status_badge_class("draft"), do: "draft"
  defp status_badge_class("running"), do: "running"
  defp status_badge_class("paused"), do: "paused"
  defp status_badge_class("completed"), do: "completed"
  defp status_badge_class(_), do: "draft"

  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
  defp format_datetime(_), do: "N/A"

  defp variant_summary(variants) when is_map(variants) do
    variants
    |> Enum.map(fn {name, config} ->
      "#{name} (#{config["weight"]}%)"
    end)
    |> Enum.join(", ")
  end
  defp variant_summary(_), do: "N/A"
end
