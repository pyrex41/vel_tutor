defmodule ViralEngineWeb.PerformanceReportLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{PerformanceReportContext, Workers.PerformanceReportWorker}
  require Logger

  @impl true
  def mount(%{"id" => report_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Require admin role
    unless user.role == "admin" do
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: "/dashboard")}
    else
      report = PerformanceReportContext.get_report(report_id)

      if report do
        {:ok, assign(socket, :report, report) |> assign(:user, user) |> assign(:view_mode, :detail)}
      else
        {:ok,
         socket
         |> put_flash(:error, "Report not found")
         |> redirect(to: "/dashboard/reports")}
      end
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Require admin role
    unless user.role == "admin" do
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: "/dashboard")}
    else
      reports = PerformanceReportContext.list_reports(limit: 20)

      {:ok,
       socket
       |> assign(:reports, reports)
       |> assign(:user, user)
       |> assign(:view_mode, :list)}
    end
  end

  @impl true
  def handle_event("generate_report", %{"type" => report_type}, socket) do
    case report_type do
      "weekly" ->
        {:ok, _job} = PerformanceReportWorker.schedule_weekly_report()
        {:noreply, put_flash(socket, :info, "Weekly report generation scheduled")}

      "monthly" ->
        {:ok, _job} = PerformanceReportWorker.schedule_monthly_report()
        {:noreply, put_flash(socket, :info, "Monthly report generation scheduled")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deliver_report", %{"report_id" => report_id, "emails" => emails_str}, socket) do
    emails = String.split(emails_str, ",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    if length(emails) > 0 do
      case PerformanceReportContext.deliver_report(report_id, emails) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Report delivered to #{length(emails)} recipients")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to deliver report")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please enter at least one email address")}
    end
  end

  @impl true
  def render(%{view_mode: :list} = assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Performance Reports</h1>
          <p class="mt-2 text-sm text-gray-600">
            Weekly and monthly viral loop performance reports
          </p>
        </div>

        <div class="flex space-x-2">
          <button
            phx-click="generate_report"
            phx-value-type="weekly"
            class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 text-sm"
          >
            Generate Weekly Report
          </button>
          <button
            phx-click="generate_report"
            phx-value-type="monthly"
            class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 text-sm"
          >
            Generate Monthly Report
          </button>
        </div>
      </div>

      <!-- Reports List -->
      <div class="bg-white shadow-md rounded-lg overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Period
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Type
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                K-Factor
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Conversions
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Health
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= if length(@reports) > 0 do %>
              <%= for report <- @reports do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Date.to_string(report.report_period_start) %> - <%= Date.to_string(report.report_period_end) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"px-2 py-1 text-xs rounded-full #{type_badge_color(report.report_type)}"}>
                      <%= String.capitalize(report.report_type) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-semibold text-gray-900"><%= Float.round(report.k_factor, 2) %></div>
                    <div class={"text-xs #{trend_color(report.k_factor_trend)}"}>
                      <%= trend_icon(report.k_factor_trend) %> <%= report.k_factor_change_pct %>%
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= report.total_conversions %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-semibold text-gray-900"><%= Float.round(report.health_score, 1) %></div>
                    <div class="text-xs text-gray-500">Flags: <%= report.fraud_flags %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"px-2 py-1 text-xs rounded-full #{status_badge_color(report.delivery_status)}"}>
                      <%= String.capitalize(report.delivery_status) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm">
                    <a
                      href={"/dashboard/reports/#{report.id}"}
                      class="text-indigo-600 hover:text-indigo-900 mr-3"
                    >
                      View
                    </a>
                  </td>
                </tr>
              <% end %>
            <% else %>
              <tr>
                <td colspan="7" class="px-6 py-8 text-center text-sm text-gray-500">
                  No reports available. Generate your first report above.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def render(%{view_mode: :detail} = assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-6">
        <a href="/dashboard/reports" class="text-indigo-600 hover:text-indigo-900 text-sm">
          ← Back to Reports
        </a>
      </div>

      <!-- Report Header -->
      <div class="bg-gradient-to-r from-indigo-600 to-purple-600 rounded-lg shadow-lg p-8 mb-6 text-white">
        <h1 class="text-3xl font-bold mb-2">Performance Report</h1>
        <p class="text-lg">
          <%= Date.to_string(@report.report_period_start) %> - <%= Date.to_string(@report.report_period_end) %>
        </p>
        <div class="mt-4 flex items-center space-x-6">
          <div>
            <span class="text-sm opacity-90">Type:</span>
            <span class="ml-2 font-semibold"><%= String.capitalize(@report.report_type) %></span>
          </div>
          <div>
            <span class="text-sm opacity-90">Status:</span>
            <span class="ml-2 font-semibold"><%= String.capitalize(@report.delivery_status) %></span>
          </div>
        </div>
      </div>

      <!-- Key Metrics -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="text-sm text-gray-600 mb-2">K-Factor</div>
          <div class="text-3xl font-bold text-indigo-600"><%= Float.round(@report.k_factor, 2) %></div>
          <div class={"text-sm mt-2 #{trend_color(@report.k_factor_trend)}"}>
            <%= trend_icon(@report.k_factor_trend) %> <%= @report.k_factor_change_pct %>% vs previous
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="text-sm text-gray-600 mb-2">Conversions</div>
          <div class="text-3xl font-bold text-gray-900"><%= @report.total_conversions %></div>
          <div class="text-sm mt-2 text-gray-500">
            <%= Float.round(@report.conversion_rate, 2) %>% rate
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="text-sm text-gray-600 mb-2">Health Score</div>
          <div class={"text-3xl font-bold #{health_score_color(@report.health_score)}"}>
            <%= Float.round(@report.health_score, 1) %>
          </div>
          <div class="text-sm mt-2 text-gray-500">
            <%= @report.fraud_flags %> fraud flags
          </div>
        </div>
      </div>

      <!-- Engagement Metrics -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Engagement Metrics</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <div class="text-sm text-gray-600">Active Users</div>
            <div class="text-2xl font-semibold text-gray-900"><%= @report.active_users %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Viral Links Created</div>
            <div class="text-2xl font-semibold text-gray-900"><%= @report.viral_links_created %></div>
          </div>
          <div>
            <div class="text-sm text-gray-600">Links Clicked</div>
            <div class="text-2xl font-semibold text-gray-900"><%= @report.viral_links_clicked %></div>
          </div>
        </div>
      </div>

      <!-- Loop Performance -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Loop Performance by Source</h2>
        <div class="space-y-3">
          <%= for {source, perf} <- @report.loop_performance do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
              <div>
                <div class="font-medium text-gray-900"><%= source_display_name(source) %></div>
                <div class="text-sm text-gray-600">
                  <%= perf["invites"] || perf[:invites] %> invites → <%= perf["conversions"] || perf[:conversions] %> conversions
                </div>
              </div>
              <div class="text-right">
                <div class="text-lg font-semibold text-indigo-600">
                  <%= Float.round((perf["k_factor"] || perf[:k_factor] || 0.0) * 1.0, 2) %>
                </div>
                <div class="text-xs text-gray-500">K-factor</div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Top Referrers -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Top Referrers</h2>
        <table class="min-w-full">
          <thead>
            <tr class="border-b">
              <th class="py-2 text-left text-sm font-medium text-gray-600">User ID</th>
              <th class="py-2 text-right text-sm font-medium text-gray-600">Invites</th>
              <th class="py-2 text-right text-sm font-medium text-gray-600">Conversions</th>
              <th class="py-2 text-right text-sm font-medium text-gray-600">Conv Rate</th>
            </tr>
          </thead>
          <tbody>
            <%= for ref <- Enum.take(@report.top_referrers, 5) do %>
              <tr class="border-b border-gray-100">
                <td class="py-2 text-sm text-gray-900"><%= ref["user_id"] || ref[:user_id] %></td>
                <td class="py-2 text-right text-sm text-gray-900"><%= ref["invites"] || ref[:invites] %></td>
                <td class="py-2 text-right text-sm text-gray-900"><%= ref["conversions"] || ref[:conversions] %></td>
                <td class="py-2 text-right text-sm text-indigo-600 font-medium">
                  <%= Float.round(((ref["conversion_rate"] || ref[:conversion_rate] || 0.0) * 1.0), 1) %>%
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <!-- Insights -->
      <div class="bg-blue-50 rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Key Insights</h2>
        <div class="space-y-2">
          <%= for insight <- @report.insights do %>
            <div class="flex items-start space-x-2">
              <span class="text-blue-600 font-bold">•</span>
              <span class="text-sm text-gray-700"><%= insight %></span>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Recommendations -->
      <div class="bg-yellow-50 rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Recommendations</h2>
        <div class="space-y-2">
          <%= for rec <- @report.recommendations do %>
            <div class="flex items-start space-x-2">
              <span class="text-yellow-600 font-bold">→</span>
              <span class="text-sm text-gray-700"><%= rec %></span>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Delivery Actions -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Deliver Report</h2>
        <form phx-submit="deliver_report">
          <input type="hidden" name="report_id" value={@report.id} />
          <div class="flex space-x-4">
            <input
              type="text"
              name="emails"
              placeholder="email1@example.com, email2@example.com"
              class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            />
            <button
              type="submit"
              class="px-6 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
            >
              Send Email
            </button>
          </div>
        </form>
        <%= if @report.delivery_status == "delivered" && @report.delivered_at do %>
          <div class="mt-3 text-sm text-gray-600">
            Delivered <%= time_ago(@report.delivered_at) %> to <%= length(@report.recipient_emails) %> recipient(s)
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  defp type_badge_color(type) do
    case type do
      "weekly" -> "bg-blue-100 text-blue-800"
      "monthly" -> "bg-purple-100 text-purple-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_badge_color(status) do
    case status do
      "delivered" -> "bg-green-100 text-green-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      "failed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp trend_color(trend) do
    case trend do
      "up" -> "text-green-600"
      "down" -> "text-red-600"
      _ -> "text-gray-600"
    end
  end

  defp trend_icon(trend) do
    case trend do
      "up" -> "↑"
      "down" -> "↓"
      _ -> "→"
    end
  end

  defp health_score_color(score) when score >= 90, do: "text-green-600"
  defp health_score_color(score) when score >= 75, do: "text-blue-600"
  defp health_score_color(score) when score >= 60, do: "text-yellow-600"
  defp health_score_color(_), do: "text-red-600"

  defp source_display_name(source) when is_binary(source) do
    case source do
      "buddy_challenge" -> "Buddy Challenges"
      "results_rally" -> "Results Rallies"
      "parent_share" -> "Parent Shares"
      "prep_pack" -> "Prep Packs"
      "study_session" -> "Study Sessions"
      "auto_challenge" -> "Auto Challenges"
      "progress_reel" -> "Progress Reels"
      _ -> String.capitalize(source)
    end
  end
  defp source_display_name(source), do: to_string(source)

  defp time_ago(datetime) when not is_nil(datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86400 -> "#{div(seconds, 3600)} hours ago"
      true -> "#{div(seconds, 86400)} days ago"
    end
  end
  defp time_ago(_), do: "never"
end
