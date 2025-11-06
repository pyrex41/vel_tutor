defmodule ViralEngineWeb.Phase3DashboardLive do
  @moduledoc """
  Real-time dashboard for Phase 3 metrics:
  - Trust & Safety statistics
  - Session Intelligence pipeline metrics
  - Viral loop K-factors (ProudParent, TutorSpotlight)
  - Compliance monitoring (COPPA/FERPA)
  - Weekly recap generation status
  """

  use ViralEngineWeb, :live_view
  require Logger

  alias ViralEngine.{Repo, TutoringSession, WeeklyRecap, DeviceFlag, ParentalConsent}
  alias ViralEngine.Integration.{AnalyticsClient, AttributionClient}
  import Ecto.Query

  @refresh_interval 30_000 # Refresh every 30 seconds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Schedule periodic updates
      Process.send_after(self(), :update_metrics, @refresh_interval)
    end

    socket =
      socket
      |> assign(:page_title, "Phase 3 Dashboard")
      |> assign(:loading, true)
      |> load_metrics()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    # Schedule next update
    Process.send_after(self(), :update_metrics, @refresh_interval)

    # Reload metrics
    {:noreply, load_metrics(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-gray-50 min-h-screen">
      <h1 class="text-3xl font-bold mb-6 text-gray-800">Phase 3: Trust, Intelligence & Viral Loops</h1>

      <%= if @loading do %>
        <div class="text-center py-12">
          <p class="text-gray-600">Loading metrics...</p>
        </div>
      <% else %>
        <!-- Trust & Safety Section -->
        <section class="mb-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">Trust & Safety</h2>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Total Checks (24h)</p>
              <p class="text-3xl font-bold text-blue-600"><%= @trust_safety.total_checks %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Blocked Actions</p>
              <p class="text-3xl font-bold text-red-600"><%= @trust_safety.blocked_actions %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Fraud Score Avg</p>
              <p class="text-3xl font-bold text-yellow-600"><%= @trust_safety.avg_fraud_score %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Active Flags</p>
              <p class="text-3xl font-bold text-orange-600"><%= @trust_safety.active_flags %></p>
            </div>
          </div>
        </section>

        <!-- Compliance Section -->
        <section class="mb-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">COPPA/FERPA Compliance</h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Minors Requiring Consent</p>
              <p class="text-3xl font-bold text-purple-600"><%= @compliance.minors_count %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Active Consents</p>
              <p class="text-3xl font-bold text-green-600"><%= @compliance.active_consents %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Pending Consents</p>
              <p class="text-3xl font-bold text-yellow-600"><%= @compliance.pending_consents %></p>
            </div>
          </div>
        </section>

        <!-- Session Intelligence Section -->
        <section class="mb-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">Session Intelligence Pipeline</h2>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Sessions Processed (24h)</p>
              <p class="text-3xl font-bold text-blue-600"><%= @session_intelligence.processed_count %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Pending Processing</p>
              <p class="text-3xl font-bold text-orange-600"><%= @session_intelligence.pending_count %></p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Avg Processing Time</p>
              <p class="text-3xl font-bold text-green-600"><%= @session_intelligence.avg_processing_time %>s</p>
            </div>
            <div class="bg-white p-6 rounded-lg shadow">
              <p class="text-sm text-gray-600 mb-2">Actions Generated</p>
              <p class="text-3xl font-bold text-indigo-600"><%= @session_intelligence.actions_generated %></p>
            </div>
          </div>
        </section>

        <!-- Viral Loops Section -->
        <section class="mb-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">Viral Loops Performance</h2>

          <!-- ProudParent Loop -->
          <div class="mb-6">
            <h3 class="text-xl font-medium mb-3 text-gray-600">ProudParent Loop</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">Weekly Recaps Generated</p>
                <p class="text-3xl font-bold text-blue-600"><%= @proud_parent.recaps_generated %></p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">Share Rate</p>
                <p class="text-3xl font-bold text-green-600"><%= @proud_parent.share_rate %>%</p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">Conversions (7d)</p>
                <p class="text-3xl font-bold text-purple-600"><%= @proud_parent.conversions %></p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">K-Factor</p>
                <p class="text-3xl font-bold text-pink-600"><%= @proud_parent.k_factor %></p>
              </div>
            </div>
          </div>

          <!-- TutorSpotlight Loop -->
          <div>
            <h3 class="text-xl font-medium mb-3 text-gray-600">TutorSpotlight Loop</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">5-Star Sessions (7d)</p>
                <p class="text-3xl font-bold text-blue-600"><%= @tutor_spotlight.five_star_sessions %></p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">Share Packs Created</p>
                <p class="text-3xl font-bold text-green-600"><%= @tutor_spotlight.share_packs_created %></p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">Referral Bookings</p>
                <p class="text-3xl font-bold text-purple-600"><%= @tutor_spotlight.referral_bookings %></p>
              </div>
              <div class="bg-white p-6 rounded-lg shadow">
                <p class="text-sm text-gray-600 mb-2">K-Factor</p>
                <p class="text-3xl font-bold text-pink-600"><%= @tutor_spotlight.k_factor %></p>
              </div>
            </div>
          </div>
        </section>

        <!-- System Health Section -->
        <section class="mb-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">System Health</h2>
          <div class="bg-white p-6 rounded-lg shadow">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p class="text-sm text-gray-600 mb-2">Last Recap Generation</p>
                <p class="text-lg font-medium text-gray-800"><%= @system_health.last_recap_run %></p>
              </div>
              <div>
                <p class="text-sm text-gray-600 mb-2">TrustSafety Agent Status</p>
                <p class="text-lg font-medium <%= if @system_health.trust_safety_alive, do: "text-green-600", else: "text-red-600" %>">
                  <%= if @system_health.trust_safety_alive, do: "✓ Running", else: "✗ Stopped" %>
                </p>
              </div>
            </div>
          </div>
        </section>

        <!-- Footer -->
        <div class="text-center text-sm text-gray-500 mt-8">
          Last updated: <%= @last_updated %> | Auto-refreshes every 30 seconds
        </div>
      <% end %>
    </div>
    """
  end

  defp load_metrics(socket) do
    socket
    |> assign(:loading, false)
    |> assign(:trust_safety, fetch_trust_safety_metrics())
    |> assign(:compliance, fetch_compliance_metrics())
    |> assign(:session_intelligence, fetch_session_intelligence_metrics())
    |> assign(:proud_parent, fetch_proud_parent_metrics())
    |> assign(:tutor_spotlight, fetch_tutor_spotlight_metrics())
    |> assign(:system_health, fetch_system_health())
    |> assign(:last_updated, format_timestamp(DateTime.utc_now()))
  end

  defp fetch_trust_safety_metrics do
    # In production, these would come from analytics/metrics service
    # For now, calculate from DeviceFlags table
    yesterday = DateTime.add(DateTime.utc_now(), -86400, :second)

    total_flags = Repo.aggregate(DeviceFlag, :count, :id)
    active_flags = Repo.aggregate(from(d in DeviceFlag, where: d.blocked == true), :count, :id)

    blocked_actions =
      Repo.aggregate(
        from(d in DeviceFlag, where: d.blocked_at >= ^yesterday),
        :count,
        :id
      )

    avg_fraud_score =
      case Repo.aggregate(DeviceFlag, :avg, :risk_score) do
        nil -> 0.0
        score -> Float.round(score, 1)
      end

    %{
      total_checks: total_flags * 10,
      # Estimate
      blocked_actions: blocked_actions,
      avg_fraud_score: avg_fraud_score,
      active_flags: active_flags
    }
  end

  defp fetch_compliance_metrics do
    minors_count =
      Repo.aggregate(
        from(u in ViralEngine.Accounts.User, where: not is_nil(u.age) and u.age < 13),
        :count,
        :id
      )

    active_consents =
      Repo.aggregate(
        from(c in ParentalConsent, where: c.consent_given == true and is_nil(c.withdrawn_at)),
        :count,
        :id
      )

    pending_consents = max(0, minors_count - active_consents)

    %{
      minors_count: minors_count,
      active_consents: active_consents,
      pending_consents: pending_consents
    }
  end

  defp fetch_session_intelligence_metrics do
    yesterday = DateTime.add(DateTime.utc_now(), -86400, :second)

    processed_count =
      Repo.aggregate(
        from(s in TutoringSession, where: s.processed == true and s.processed_at >= ^yesterday),
        :count,
        :id
      )

    pending_count =
      Repo.aggregate(
        from(s in TutoringSession,
          where: s.processed == false and not is_nil(s.ended_at)
        ),
        :count,
        :id
      )

    # Estimate actions generated (3 per session: student, tutor, parent)
    actions_generated = processed_count * 3

    %{
      processed_count: processed_count,
      pending_count: pending_count,
      avg_processing_time: 2.3,
      # Stub
      actions_generated: actions_generated
    }
  end

  defp fetch_proud_parent_metrics do
    week_ago = Date.add(Date.utc_today(), -7)

    recaps_generated =
      Repo.aggregate(
        from(r in WeeklyRecap, where: r.inserted_at >= ^week_ago),
        :count,
        :id
      )

    shared_recaps =
      Repo.aggregate(
        from(r in WeeklyRecap, where: r.shared == true and r.inserted_at >= ^week_ago),
        :count,
        :id
      )

    share_rate =
      if recaps_generated > 0 do
        Float.round(shared_recaps / recaps_generated * 100, 1)
      else
        0.0
      end

    # Stub conversions - in production, fetch from AttributionClient
    conversions = trunc(shared_recaps * 0.15)
    # 15% conversion estimate

    k_factor =
      if shared_recaps > 0 do
        Float.round(conversions / shared_recaps, 2)
      else
        0.0
      end

    %{
      recaps_generated: recaps_generated,
      share_rate: share_rate,
      conversions: conversions,
      k_factor: k_factor
    }
  end

  defp fetch_tutor_spotlight_metrics do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 86400, :second)

    five_star_sessions =
      Repo.aggregate(
        from(s in TutoringSession,
          where: s.rating == 5 and s.ended_at >= ^week_ago
        ),
        :count,
        :id
      )

    # Stub share packs (assume 60% of 5-star sessions trigger sharing)
    share_packs_created = trunc(five_star_sessions * 0.6)

    # Stub referral bookings (15% conversion)
    referral_bookings = trunc(share_packs_created * 0.15)

    k_factor =
      if share_packs_created > 0 do
        Float.round(referral_bookings / share_packs_created, 2)
      else
        0.0
      end

    %{
      five_star_sessions: five_star_sessions,
      share_packs_created: share_packs_created,
      referral_bookings: referral_bookings,
      k_factor: k_factor
    }
  end

  defp fetch_system_health do
    # Check if TrustSafety GenServer is running
    trust_safety_alive =
      case Process.whereis(ViralEngine.Agents.TrustSafety) do
        nil -> false
        _pid -> true
      end

    # Get last recap generation time
    last_recap =
      from(r in WeeklyRecap, order_by: [desc: r.inserted_at], limit: 1)
      |> Repo.one()

    last_recap_run =
      case last_recap do
        nil -> "Never"
        recap -> format_timestamp(recap.inserted_at)
      end

    %{
      trust_safety_alive: trust_safety_alive,
      last_recap_run: last_recap_run
    }
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
end
