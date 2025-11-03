# Varsity Tutors Viral Growth Engine
## Phased Implementation Plan

I'll break this into **4 progressive phases**, each shippable and testable independently. Each phase builds on the previous, allowing you to validate assumptions and iterate before full commitment.

---

# PHASE 1: Foundation & Infrastructure
**Timeline: Week 1-2 (10 days) | Goal: Shippable Attribution + Agent Framework**

## Scope

Build the core platform infrastructure without viral loops, proving out the agent architecture and attribution system. Ship a working "invite a friend" feature as proof-of-concept.

## Deliverables

### 1.1 Core Phoenix Application
```elixir
# Project structure
viral_engine/
├── lib/
│   ├── viral_engine/
│   │   ├── agents/              # Agent GenServers
│   │   ├── attribution/         # Smart links & tracking
│   │   ├── analytics/           # Event logging
│   │   └── compliance/          # COPPA/FERPA checks
│   └── viral_engine_web/
│       ├── live/                # LiveView pages
│       └── channels/            # Real-time presence
├── priv/repo/migrations/
└── config/
```

### 1.2 Database Schema (Minimal)

```elixir
# priv/repo/migrations/20250103_phase1_schema.exs
defmodule ViralEngine.Repo.Migrations.Phase1Schema do
  use Ecto.Migration

  def change do
    # Smart Links
    create table(:smart_links) do
      add :code, :string, null: false
      add :signature, :string, null: false
      add :referrer_id, :integer, null: false
      add :context, :map
      add :click_count, :integer, default: 0
      add :conversion_count, :integer, default: 0
      add :expires_at, :utc_datetime
      timestamps()
    end
    create unique_index(:smart_links, [:code])
    create index(:smart_links, [:referrer_id])

    # Attributions
    create table(:attributions) do
      add :link_id, references(:smart_links, on_delete: :delete_all)
      add :referrer_id, :integer, null: false
      add :referee_id, :integer, null: false
      add :attributed_at, :utc_datetime
      timestamps()
    end
    create index(:attributions, [:referrer_id])
    create index(:attributions, [:referee_id])

    # Events (time-series, partitioned by date if needed)
    create table(:viral_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :event_type, :string, null: false
      add :user_id, :integer
      add :link_id, :integer
      add :properties, :map
      add :timestamp, :utc_datetime_usec, null: false
    end
    create index(:viral_events, [:event_type])
    create index(:viral_events, [:user_id])
    create index(:viral_events, [:timestamp])

    # Agent Decisions (for auditability)
    create table(:agent_decisions) do
      add :agent_name, :string, null: false
      add :user_id, :integer
      add :decision_type, :string
      add :rationale, :text
      add :features, :map
      add :outcome, :string
      add :timestamp, :utc_datetime
      timestamps()
    end
    create index(:agent_decisions, [:agent_name])
    create index(:agent_decisions, [:timestamp])
  end
end
```

### 1.3 Attribution System (Complete)

```elixir
defmodule ViralEngine.Attribution do
  @moduledoc """
  Smart link generation, tracking, and attribution.
  Core of all viral loops.
  """

  alias ViralEngine.Repo
  alias ViralEngine.Schemas.{SmartLink, Attribution}

  def create_link(params) do
    code = generate_short_code()
    signature = sign_code(code, params)

    link = %SmartLink{
      code: code,
      signature: signature,
      referrer_id: params.referrer_id,
      context: params.context,
      expires_at: DateTime.add(DateTime.utc_now(), 30 * 86400)
    }

    case Repo.insert(link) do
      {:ok, link} ->
        {:ok, %{
          url: build_url(link),
          deep_link: build_deep_link(link),
          code: code
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def track_click(code) do
    with {:ok, link} <- get_link(code),
         :ok <- log_event(:link_clicked, link) do
      
      Repo.update_all(
        from(l in SmartLink, where: l.id == ^link.id),
        inc: [click_count: 1]
      )

      {:ok, link}
    end
  end

  def attribute_signup(code, new_user_id) do
    with {:ok, link} <- get_link(code) do
      attribution = %Attribution{
        link_id: link.id,
        referrer_id: link.referrer_id,
        referee_id: new_user_id,
        attributed_at: DateTime.utc_now()
      }

      case Repo.insert(attribution) do
        {:ok, attr} ->
          log_event(:signup_attributed, link, new_user_id)
          
          # Notify both users (rewards handled in Phase 2)
          notify_attribution(attr)
          
          {:ok, attr}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Helpers
  defp generate_short_code do
    # 8-char alphanumeric
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end

  defp sign_code(code, params) do
    secret = Application.get_env(:viral_engine, :link_signing_secret)
    payload = "#{code}:#{params.referrer_id}"
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.url_encode64(padding: false)
  end

  defp build_url(link) do
    base = Application.get_env(:viral_engine, :base_url)
    "#{base}/r/#{link.code}"
  end

  defp build_deep_link(link) do
    params = URI.encode_query(%{
      ref: link.code,
      context: Jason.encode!(link.context)
    })
    "varsitytutors://join?#{params}"
  end

  defp get_link(code) do
    case Repo.get_by(SmartLink, code: code) do
      nil -> {:error, :not_found}
      link -> {:ok, link}
    end
  end

  defp log_event(type, link, user_id \\ nil) do
    ViralEngine.Analytics.log(%{
      event_type: to_string(type),
      user_id: user_id || link.referrer_id,
      link_id: link.id,
      properties: %{},
      timestamp: DateTime.utc_now()
    })
  end

  defp notify_attribution(attr) do
    # Send notifications (implement in your notification system)
    # For now, just broadcast via PubSub
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "user:#{attr.referrer_id}",
      {:new_referral, attr}
    )
  end
end
```

### 1.4 Agent Framework (Stub Orchestrator)

```elixir
defmodule ViralEngine.Agents.Orchestrator do
  use GenServer
  require Logger

  @moduledoc """
  Phase 1: Simple event router with eligibility checking.
  No complex loop selection yet - just routes to handlers.
  """

  defmodule State do
    defstruct [:metrics_pid]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trigger_event(event) do
    GenServer.call(__MODULE__, {:trigger_event, event}, 10_000)
  end

  def init(_opts) do
    {:ok, %State{}}
  end

  def handle_call({:trigger_event, event}, _from, state) do
    Logger.info("Orchestrator received event: #{inspect(event)}")
    
    # Phase 1: Just log and return success
    # Phase 2+: Add loop routing logic
    
    decision = %{
      action: :no_action,
      rationale: "Phase 1: Event logged, no loops active yet"
    }

    log_decision(event, decision)

    {:reply, {:ok, decision}, state}
  end

  defp log_decision(event, decision) do
    ViralEngine.Analytics.log_decision(%{
      agent_name: "orchestrator",
      user_id: event.user_id,
      decision_type: "event_routing",
      rationale: decision.rationale,
      features: %{event_type: event.type},
      outcome: "logged",
      timestamp: DateTime.utc_now()
    })
  end
end
```

### 1.5 MCP Deployment (Fly.io)

```bash
#!/bin/bash
# deploy_phase1.sh

# Deploy Orchestrator as MCP server
fly mcp launch \
  "mix run --no-halt" \
  --server viral-orchestrator \
  --region ord \
  --vm-size shared-cpu-1x \
  --auto-stop 0 \
  --secret DATABASE_URL="${DATABASE_URL}" \
  --secret SECRET_KEY_BASE="${SECRET_KEY_BASE}"

echo "✅ Phase 1 MCP server deployed"
echo "Test with: fly mcp inspect --server viral-orchestrator"
```

### 1.6 Simple "Invite a Friend" Feature

```elixir
defmodule ViralEngineWeb.InviteLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Generate invite link
    {:ok, link_data} = ViralEngine.Attribution.create_link(%{
      referrer_id: user.id,
      context: %{source: "manual_invite"}
    })

    socket = 
      socket
      |> assign(:user, user)
      |> assign(:invite_link, link_data.url)
      |> assign(:copied, false)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto p-6">
      <h2 class="text-2xl font-bold mb-4">Invite a Friend</h2>
      
      <div class="bg-gray-100 p-4 rounded-lg mb-4">
        <p class="text-sm text-gray-600 mb-2">Your invite link:</p>
        <div class="flex gap-2">
          <input 
            type="text" 
            value={@invite_link} 
            readonly 
            class="flex-1 p-2 border rounded"
          />
          <button 
            phx-click="copy_link"
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            <%= if @copied, do: "Copied!", else: "Copy" %>
          </button>
        </div>
      </div>

      <div class="space-y-2">
        <a 
          href={"sms:?body=Join me on Varsity Tutors! #{@invite_link}"}
          class="block w-full p-3 bg-green-500 text-white text-center rounded hover:bg-green-600"
        >
          📱 Send via SMS
        </a>
        
        <a 
          href={"https://wa.me/?text=#{URI.encode_www_form("Join me on Varsity Tutors! " <> @invite_link)}"}
          class="block w-full p-3 bg-green-600 text-white text-center rounded hover:bg-green-700"
        >
          💬 Share on WhatsApp
        </a>
      </div>
    </div>
    """
  end

  def handle_event("copy_link", _params, socket) do
    # Client-side copy happens via JS hook
    {:noreply, assign(socket, :copied, true)}
  end
end
```

### 1.7 Link Landing Page

```elixir
defmodule ViralEngineWeb.ReferralController do
  use ViralEngineWeb, :controller

  def show(conn, %{"code" => code}) do
    case ViralEngine.Attribution.track_click(code) do
      {:ok, link} ->
        # Redirect to signup with context
        conn
        |> put_session(:referral_code, code)
        |> redirect(to: ~p"/signup?ref=#{code}")
      
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Invalid invite link")
        |> redirect(to: ~p"/")
    end
  end
end
```

## Success Criteria (Phase 1)

- [ ] Smart link generation working (100% success rate)
- [ ] Click tracking functional
- [ ] Attribution on signup working
- [ ] MCP Orchestrator deployed and responding
- [ ] Manual invite feature live
- [ ] At least 10 test invites → signups tracked correctly
- [ ] Decision logging visible in DB
- [ ] Sub-100ms link generation latency

## Phase 1 Metrics Dashboard

```elixir
defmodule ViralEngineWeb.Phase1DashboardLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :refresh)
    end

    metrics = fetch_metrics()

    {:ok, assign(socket, :metrics, metrics)}
  end

  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, :metrics, fetch_metrics())}
  end

  defp fetch_metrics do
    %{
      total_links_created: Repo.aggregate(SmartLink, :count),
      total_clicks: Repo.aggregate(SmartLink, :sum, :click_count),
      total_signups: Repo.aggregate(Attribution, :count),
      click_through_rate: calculate_ctr(),
      signup_conversion_rate: calculate_scr()
    }
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-3xl font-bold mb-6">Phase 1: Attribution System</h1>
      
      <div class="grid grid-cols-3 gap-4">
        <div class="bg-white p-6 rounded-lg shadow">
          <div class="text-sm text-gray-500">Links Created</div>
          <div class="text-3xl font-bold"><%= @metrics.total_links_created %></div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow">
          <div class="text-sm text-gray-500">Total Clicks</div>
          <div class="text-3xl font-bold"><%= @metrics.total_clicks %></div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow">
          <div class="text-sm text-gray-500">Signups</div>
          <div class="text-3xl font-bold"><%= @metrics.total_signups %></div>
        </div>
      </div>

      <div class="mt-6 bg-blue-50 p-4 rounded">
        <p class="font-semibold">✅ Phase 1 Complete When:</p>
        <ul class="mt-2 space-y-1">
          <li>• Attribution system proven (10+ tracked signups)</li>
          <li>• MCP deployment working</li>
          <li>• Ready to add viral loops in Phase 2</li>
        </ul>
      </div>
    </div>
    """
  end
end
```

## What Phase 1 Proves

1. **Technical feasibility** of Elixir + MCP architecture
2. **Attribution works** end-to-end
3. **Fly.io deployment** is stable
4. **Basic viral mechanics** (link → click → signup) function
5. **Team velocity** on this stack

## Phase 1 Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Fly.io MCP unfamiliar | Allocate 2 days for setup/testing |
| Link signing issues | Test suite with edge cases |
| Elixir learning curve | Pair programming, code reviews |
| Attribution edge cases | Device fingerprinting stub for Phase 2 |

---

**Next: [Phase 2 PRD](continuing...)**

Ready for Phase 2 (Buddy Challenge + Results Rally)?
