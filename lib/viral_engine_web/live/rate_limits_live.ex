defmodule ViralEngineWeb.RateLimitsLive do
  use Phoenix.LiveView

  alias ViralEngine.{RateLimitContext, RBACContext}

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]
    current_org_id = session["current_organization_id"]

    # Check if user has permission to view rate limits
    has_permission =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if has_permission do
      rate_limits = RateLimitContext.list_rate_limits()

      socket =
        socket
        |> assign(:rate_limits, rate_limits)
        |> assign(:current_user_id, current_user_id)
        |> assign(:current_org_id, current_org_id)
        |> assign(:has_permission, true)

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:has_permission, false)
        |> put_flash(:error, "You don't have permission to view rate limits")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    rate_limits = RateLimitContext.list_rate_limits()
    {:noreply, assign(socket, :rate_limits, rate_limits)}
  end

  @impl true
  def handle_event("reset_counters", %{"id" => rate_limit_id}, socket) do
    case RateLimitContext.delete_rate_limit(rate_limit_id) do
      {:ok, _} ->
        rate_limits = RateLimitContext.list_rate_limits()

        socket =
          socket
          |> assign(:rate_limits, rate_limits)
          |> put_flash(:info, "Rate limit counters reset successfully")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset rate limit counters")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rate-limits-dashboard">
      <div class="header">
        <h1>Rate Limits Dashboard</h1>
        <button phx-click="refresh" class="btn btn-primary">Refresh</button>
      </div>

      <%= if @has_permission do %>
        <div class="rate-limits-table">
          <table class="table">
            <thead>
              <tr>
                <th>Type</th>
                <th>ID</th>
                <th>Tasks/Hour</th>
                <th>Current Hourly</th>
                <th>Concurrent Tasks</th>
                <th>Current Concurrent</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for rate_limit <- @rate_limits do %>
                <tr>
                  <td><%= if rate_limit.user_id, do: "User", else: "Organization" %></td>
                  <td><%= rate_limit.user_id || rate_limit.organization_id %></td>
                  <td><%= rate_limit.tasks_per_hour %></td>
                  <td>
                    <span class={"count #{if rate_limit.current_hourly_count >= rate_limit.tasks_per_hour, do: "limit-exceeded", else: "normal"}"}>
                      <%= rate_limit.current_hourly_count %>
                    </span>
                  </td>
                  <td><%= rate_limit.concurrent_tasks %></td>
                  <td>
                    <span class={"count #{if rate_limit.current_concurrent_count >= rate_limit.concurrent_tasks, do: "limit-exceeded", else: "normal"}"}>
                      <%= rate_limit.current_concurrent_count %>
                    </span>
                  </td>
                  <td>
                    <button phx-click="reset_counters" phx-value-id={rate_limit.id} class="btn btn-sm btn-warning">
                      Reset Counters
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if Enum.empty?(@rate_limits) do %>
          <div class="no-data">
            <p>No custom rate limits configured. All users are using default limits.</p>
          </div>
        <% end %>
      <% else %>
        <div class="permission-denied">
          <p>You don't have permission to view this dashboard.</p>
        </div>
      <% end %>
    </div>
    """
  end
end
