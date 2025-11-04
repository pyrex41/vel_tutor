defmodule ViralEngineWeb.AlertDashboardLive do
  @moduledoc """
  Phoenix LiveView dashboard for monitoring and managing system alerts.
  """

  use Phoenix.LiveView
  alias ViralEngine.{Alert, Repo}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to alert notifications
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "alerts")
    end

    alerts = list_alerts()

    socket =
      socket
      |> assign(:alerts, alerts)
      |> assign(:filter_status, "all")
      |> assign(:filter_metric, "all")
      |> assign(:page, 1)
      |> assign(:page_size, 20)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_status = params["status"] || "all"
    filter_metric = params["metric"] || "all"
    page = String.to_integer(params["page"] || "1")

    alerts = list_alerts(filter_status, filter_metric, page, socket.assigns.page_size)

    socket =
      socket
      |> assign(:alerts, alerts)
      |> assign(:filter_status, filter_status)
      |> assign(:filter_metric, filter_metric)
      |> assign(:page, page)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status, "metric" => metric}, socket) do
    {:noreply, push_patch(socket, to: "/dashboard/alerts?status=#{status}&metric=#{metric}")}
  end

  @impl true
  def handle_event("resolve_alert", %{"alert_id" => alert_id}, socket) do
    case Repo.get(Alert, alert_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Alert not found")}

      alert ->
        changeset =
          Alert.changeset(alert, %{
            status: "resolved",
            resolved_at: NaiveDateTime.utc_now(),
            # For now, use system user - in production, get from session
            resolved_by: "system"
          })

        case Repo.update(changeset) do
          {:ok, _updated_alert} ->
            # Log the resolution to audit system
            ViralEngine.AuditLogContext.log_system_event("alert_resolved", %{
              alert_id: alert_id,
              metric_type: alert.metric_type,
              resolved_by: "system",
              resolved_at: NaiveDateTime.utc_now()
            })

            alerts =
              list_alerts(
                socket.assigns.filter_status,
                socket.assigns.filter_metric,
                socket.assigns.page,
                socket.assigns.page_size
              )

            {:noreply, assign(socket, :alerts, alerts) |> put_flash(:info, "Alert resolved")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to resolve alert")}
        end
    end
  end

  @impl true
  def handle_info(%{type: "alert"} = payload, socket) do
    # New alert received, refresh the list
    alerts =
      list_alerts(
        socket.assigns.filter_status,
        socket.assigns.filter_metric,
        socket.assigns.page,
        socket.assigns.page_size
      )

    {:noreply,
     socket
     |> assign(:alerts, alerts)
     |> put_flash(:info, "New alert: #{payload.message}")}
  end

  # Private functions

  defp format_value(value, metric_type) do
    case metric_type do
      "error_rate" -> "#{Float.round(value, 2)}%"
      "latency" -> "#{round(value)}ms"
      "cost_per_task" -> "$#{Float.round(value, 4)}"
      "failures" -> "#{round(value)}"
      _ -> "#{value}"
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp list_alerts(filter_status \\ "all", filter_metric \\ "all", page \\ 1, page_size \\ 20) do
    offset = (page - 1) * page_size

    query =
      from(a in Alert,
        order_by: [desc: a.inserted_at],
        limit: ^page_size,
        offset: ^offset
      )

    query =
      if filter_status != "all" do
        from(a in query, where: a.status == ^filter_status)
      else
        query
      end

    query =
      if filter_metric != "all" do
        from(a in query, where: a.metric_type == ^filter_metric)
      else
        query
      end

    Repo.all(query)
  end
end
