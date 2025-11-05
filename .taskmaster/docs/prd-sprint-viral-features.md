# Vel Tutor: Real-Time Viral Loop Features Sprint Plan

**Sprint Duration:** 34 development days (4-5 weeks)
**Team:** 2 Backend Developers + 1 Frontend Developer
**Created:** 2025-11-04
**Status:** Ready for Implementation

---

## Executive Summary

This sprint focuses on implementing the foundational real-time infrastructure and viral loop features for Vel Tutor. The plan covers 5 interconnected tasks that will enable live presence tracking, activity feeds, leaderboards, and social nudging features designed to drive engagement and viral growth.

### Sprint Goals

1. **Establish real-time infrastructure** capable of handling 5,000+ concurrent users
2. **Implement presence tracking** for global and subject-specific contexts
3. **Build activity feed system** to showcase user achievements
4. **Create mini-leaderboards** to drive competitive engagement
5. **Deploy study buddy nudges** to encourage peer-to-peer invitations

### Success Criteria

- P95 latency < 150ms for real-time updates
- Support 5,000 concurrent WebSocket connections
- 50+ events/second processing capacity
- >90% test coverage across all new code
- COPPA/FERPA compliant implementation

---

## Task #1: Set Up Real-Time Infrastructure with Phoenix Channels and PubSub

**Priority:** High | **Complexity:** 8/10 | **Duration:** 10 days | **Dependencies:** None

### Overview

Establish the foundational real-time communication layer using Phoenix Channels and PubSub to support live updates for presence, activity feeds, and leaderboards. This is the critical path that unblocks 7 other tasks.

### Subtasks

#### 1.1: Integrate Phoenix Channels into the Elixir/Phoenix Backend (3 days)

**Files to Create:**
- `lib/viral_engine_web/channels/user_socket.ex`
- `lib/viral_engine_web/channels/presence_channel.ex`
- `lib/viral_engine_web/channels/activity_channel.ex`
- `lib/viral_engine_web/channels/subject_channel.ex`
- `lib/viral_engine_web/channels/notification_channel.ex`

**Files to Modify:**
- `lib/viral_engine_web/endpoint.ex` - Add socket configuration

**Implementation Steps:**

1. **Configure User Socket:**

```elixir
# lib/viral_engine_web/channels/user_socket.ex
defmodule ViralEngineWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "presence:lobby", ViralEngineWeb.PresenceChannel
  channel "presence:subject:*", ViralEngineWeb.SubjectChannel
  channel "activity:*", ViralEngineWeb.ActivityChannel
  channel "notifications:*", ViralEngineWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case ViralEngine.Accounts.verify_socket_token(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
```

2. **Update Endpoint Configuration:**

```elixir
# lib/viral_engine_web/endpoint.ex
defmodule ViralEngineWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :viral_engine

  # Add WebSocket support
  socket "/socket", ViralEngineWeb.UserSocket,
    websocket: [
      connect_info: [:peer_data, :x_headers],
      timeout: 45_000,
      max_frame_size: 8_000_000
    ],
    longpoll: false

  # ... rest of endpoint config
end
```

3. **Create Presence Channel:**

```elixir
# lib/viral_engine_web/channels/presence_channel.ex
defmodule ViralEngineWeb.PresenceChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.Presence

  @impl true
  def join("presence:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    user = ViralEngine.Accounts.get_user!(user_id)

    {:ok, _} = Presence.track(socket, user_id, %{
      user_id: user_id,
      username: user.username,
      online_at: inspect(System.system_time(:second)),
      avatar_url: user.avatar_url,
      current_subject: nil,
      status: "online"
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("update_status", %{"status" => status}, socket) do
    user_id = socket.assigns.user_id

    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :status, status)
    end)

    {:reply, :ok, socket}
  end
end
```

**Testing Strategy:**

```elixir
# test/viral_engine_web/channels/presence_channel_test.exs
defmodule ViralEngineWeb.PresenceChannelTest do
  use ViralEngineWeb.ChannelCase
  alias ViralEngine.Presence

  setup do
    user = insert(:user)
    {:ok, _, socket} = ViralEngineWeb.UserSocket
      |> socket("user_id", %{user_id: user.id})
      |> subscribe_and_join(ViralEngineWeb.PresenceChannel, "presence:lobby")

    %{socket: socket, user: user}
  end

  test "tracks user presence after join", %{socket: socket, user: user} do
    presences = Presence.list(socket)
    assert Map.has_key?(presences, to_string(user.id))
  end

  test "updates user status", %{socket: socket, user: user} do
    ref = push(socket, "update_status", %{"status" => "studying"})
    assert_reply ref, :ok

    presences = Presence.list(socket)
    user_presence = presences[to_string(user.id)]
    assert user_presence.metas |> List.first() |> Map.get(:status) == "studying"
  end
end
```

**Acceptance Criteria:**
- [ ] Users can connect to WebSocket endpoint with JWT token
- [ ] Presence tracking works in lobby channel
- [ ] User metadata (username, avatar, status) tracked correctly
- [ ] WebSocket disconnections handled gracefully
- [ ] Test coverage > 90%

---

#### 1.2: Configure PubSub with Redis or PostgreSQL for Scalability (2 days)

**Files to Modify:**
- `config/runtime.exs`
- `mix.exs` - Add Redis adapter dependency
- `lib/viral_engine/application.ex`

**Implementation Steps:**

1. **Add Redis Adapter Dependency:**

```elixir
# mix.exs
defp deps do
  [
    # ... existing deps
    {:phoenix_pubsub_redis, "~> 3.0"}
  ]
end
```

2. **Configure Redis PubSub:**

```elixir
# config/runtime.exs
config :viral_engine, ViralEngine.PubSub,
  adapter: Phoenix.PubSub.Redis,
  host: System.get_env("REDIS_HOST", "localhost"),
  port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
  pool_size: 10,
  node_name: System.get_env("NODE_NAME", "viral_engine")
```

3. **Update Application Supervisor:**

```elixir
# lib/viral_engine/application.ex
def start(_type, _args) do
  children = [
    # Start PubSub with Redis adapter
    {Phoenix.PubSub, name: ViralEngine.PubSub, adapter: Phoenix.PubSub.Redis},

    # Start Presence
    ViralEngine.Presence,

    # ... rest of children
  ]

  opts = [strategy: :one_for_one, name: ViralEngine.Supervisor]
  Supervisor.start_link(children, opts)
end
```

4. **Create PubSub Helper Module:**

```elixir
# lib/viral_engine/pubsub_helper.ex
defmodule ViralEngine.PubSubHelper do
  @moduledoc """
  Helper functions for broadcasting events via PubSub
  """

  alias Phoenix.PubSub

  @pubsub ViralEngine.PubSub

  def broadcast_activity(event_type, data) do
    PubSub.broadcast(@pubsub, "activity:global", {:activity, event_type, data})
  end

  def broadcast_subject_activity(subject_id, event_type, data) do
    PubSub.broadcast(@pubsub, "activity:subject:#{subject_id}", {:activity, event_type, data})
  end

  def broadcast_leaderboard_update(subject_id, data) do
    PubSub.broadcast(@pubsub, "leaderboard:#{subject_id}", {:leaderboard_update, data})
  end

  def subscribe_to_activity do
    PubSub.subscribe(@pubsub, "activity:global")
  end

  def subscribe_to_subject_activity(subject_id) do
    PubSub.subscribe(@pubsub, "activity:subject:#{subject_id}")
  end
end
```

**Testing Strategy:**

```elixir
# test/viral_engine/pubsub_helper_test.exs
defmodule ViralEngine.PubSubHelperTest do
  use ViralEngine.DataCase
  alias ViralEngine.PubSubHelper

  test "broadcasts activity to global channel" do
    PubSubHelper.subscribe_to_activity()

    PubSubHelper.broadcast_activity("achievement_unlocked", %{user_id: 1, achievement: "first_streak"})

    assert_receive {:activity, "achievement_unlocked", %{user_id: 1}}
  end

  test "broadcasts to subject-specific channel" do
    subject_id = 123
    PubSubHelper.subscribe_to_subject_activity(subject_id)

    PubSubHelper.broadcast_subject_activity(subject_id, "new_high_score", %{user_id: 1, score: 95})

    assert_receive {:activity, "new_high_score", %{user_id: 1, score: 95}}
  end
end
```

**Performance Requirements:**
- Handle 50+ broadcasts/second
- < 10ms latency for local node broadcasts
- < 50ms latency for cross-node broadcasts (Redis)
- Support horizontal scaling to 3+ nodes

**Acceptance Criteria:**
- [ ] Redis PubSub configured and working
- [ ] Cross-node message delivery confirmed
- [ ] Broadcast helper functions implemented
- [ ] Performance benchmarks met
- [ ] Fallback to PostgreSQL PubSub documented

---

#### 1.3: Create Channels for Presence and Activity Feeds (3 days)

**Files to Create:**
- `lib/viral_engine_web/channels/activity_channel.ex`
- `lib/viral_engine_web/channels/subject_channel.ex`
- `lib/viral_engine/presence.ex` - Enhanced Presence module

**Implementation Steps:**

1. **Enhanced Presence Module:**

```elixir
# lib/viral_engine/presence.ex
defmodule ViralEngine.Presence do
  use Phoenix.Presence,
    otp_app: :viral_engine,
    pubsub_server: ViralEngine.PubSub

  def fetch(_topic, presences) do
    # Enrich presence data with user info from DB
    user_ids = presences |> Map.keys() |> Enum.map(&String.to_integer/1)
    users = ViralEngine.Accounts.get_users_map(user_ids)

    Enum.into(presences, %{}, fn {key, %{metas: metas}} ->
      user_id = String.to_integer(key)
      user = Map.get(users, user_id, %{})

      enriched_metas = Enum.map(metas, fn meta ->
        Map.merge(meta, %{
          username: user.username,
          avatar_url: user.avatar_url,
          display_name: user.display_name
        })
      end)

      {key, %{metas: enriched_metas}}
    end)
  end
end
```

2. **Activity Channel Implementation:**

```elixir
# lib/viral_engine_web/channels/activity_channel.ex
defmodule ViralEngineWeb.ActivityChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.{Activities, PubSubHelper}

  @impl true
  def join("activity:global", _payload, socket) do
    # Subscribe to activity PubSub topic
    PubSubHelper.subscribe_to_activity()

    # Send recent activities
    recent_activities = Activities.list_recent_activities(limit: 50)
    {:ok, %{activities: recent_activities}, socket}
  end

  def join("activity:subject:" <> subject_id, _payload, socket) do
    PubSubHelper.subscribe_to_subject_activity(subject_id)

    recent_activities = Activities.list_subject_activities(subject_id, limit: 50)
    {:ok, %{activities: recent_activities}, socket}
  end

  @impl true
  def handle_info({:activity, event_type, data}, socket) do
    push(socket, "new_activity", %{
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("react", %{"activity_id" => activity_id, "reaction" => reaction}, socket) do
    user_id = socket.assigns.user_id

    case Activities.add_reaction(activity_id, user_id, reaction) do
      {:ok, _reaction} ->
        {:reply, :ok, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
end
```

3. **Subject Channel Implementation:**

```elixir
# lib/viral_engine_web/channels/subject_channel.ex
defmodule ViralEngineWeb.SubjectChannel do
  use ViralEngineWeb, :channel
  alias ViralEngine.Presence

  @impl true
  def join("presence:subject:" <> subject_id, _payload, socket) do
    send(self(), {:after_join, subject_id})
    {:ok, assign(socket, :subject_id, subject_id)}
  end

  @impl true
  def handle_info({:after_join, subject_id}, socket) do
    user_id = socket.assigns.user_id
    user = ViralEngine.Accounts.get_user!(user_id)

    {:ok, _} = Presence.track(socket, user_id, %{
      user_id: user_id,
      username: user.username,
      subject_id: subject_id,
      online_at: inspect(System.system_time(:second)),
      current_activity: "browsing"
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("update_activity", %{"activity" => activity}, socket) do
    user_id = socket.assigns.user_id

    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :current_activity, activity)
    end)

    {:reply, :ok, socket}
  end
end
```

**Testing Strategy:**

```elixir
# test/viral_engine_web/channels/activity_channel_test.exs
defmodule ViralEngineWeb.ActivityChannelTest do
  use ViralEngineWeb.ChannelCase
  alias ViralEngine.PubSubHelper

  setup do
    user = insert(:user)
    {:ok, _, socket} = ViralEngineWeb.UserSocket
      |> socket("user_id", %{user_id: user.id})
      |> subscribe_and_join(ViralEngineWeb.ActivityChannel, "activity:global")

    %{socket: socket, user: user}
  end

  test "receives recent activities on join", %{socket: socket} do
    assert_receive %Phoenix.Socket.Reply{
      payload: %{activities: activities}
    }

    assert is_list(activities)
  end

  test "receives new activities via PubSub", %{socket: socket} do
    PubSubHelper.broadcast_activity("test_event", %{user_id: 1, data: "test"})

    assert_push "new_activity", %{event_type: "test_event"}
  end
end
```

**Acceptance Criteria:**
- [ ] Global activity channel functional
- [ ] Subject-specific channels working
- [ ] Presence tracking per subject
- [ ] Activity reactions implemented
- [ ] Real-time updates < 100ms latency

---

#### 1.4: Conduct Comprehensive Load Testing for Scalability (2 days)

**Files to Create:**
- `test/load/websocket_load_test.exs`
- `test/load/presence_load_test.exs`
- `scripts/load_test.sh`

**Implementation Steps:**

1. **WebSocket Load Test:**

```elixir
# test/load/websocket_load_test.exs
defmodule ViralEngine.LoadTest.WebSocketTest do
  use ExUnit.Case
  alias Phoenix.ChannelsClient

  @target_connections 5_000
  @events_per_second 50
  @test_duration_seconds 60

  test "handles #{@target_connections} concurrent WebSocket connections" do
    # Spawn concurrent connections
    tasks = for i <- 1..@target_connections do
      Task.async(fn ->
        connect_and_track_latency(i)
      end)
    end

    # Collect results
    results = Enum.map(tasks, &Task.await(&1, 30_000))

    # Analyze latency
    latencies = Enum.map(results, fn {:ok, latency} -> latency end)
    p50 = percentile(latencies, 50)
    p95 = percentile(latencies, 95)
    p99 = percentile(latencies, 99)

    IO.puts("P50 latency: #{p50}ms")
    IO.puts("P95 latency: #{p95}ms")
    IO.puts("P99 latency: #{p99}ms")

    # Assert performance requirements
    assert p95 < 150, "P95 latency exceeds 150ms: #{p95}ms"
  end

  defp connect_and_track_latency(user_id) do
    start_time = System.monotonic_time(:millisecond)

    {:ok, socket} = ChannelsClient.connect(
      "ws://localhost:4000/socket/websocket",
      params: %{token: generate_token(user_id)}
    )

    {:ok, _reply, _channel} = ChannelsClient.join(socket, "presence:lobby")

    end_time = System.monotonic_time(:millisecond)
    latency = end_time - start_time

    {:ok, latency}
  end

  defp percentile(list, percentile) do
    sorted = Enum.sort(list)
    index = round(length(sorted) * percentile / 100)
    Enum.at(sorted, index)
  end
end
```

2. **Load Test Script:**

```bash
#!/bin/bash
# scripts/load_test.sh

echo "Starting load test environment..."

# Start Redis
docker run -d --name redis-load-test -p 6379:6379 redis:7

# Start application in load test mode
MIX_ENV=test mix phx.server &
APP_PID=$!

# Wait for app to start
sleep 5

echo "Running WebSocket load tests..."
mix test test/load/websocket_load_test.exs --trace

echo "Running Presence load tests..."
mix test test/load/presence_load_test.exs --trace

# Cleanup
kill $APP_PID
docker stop redis-load-test
docker rm redis-load-test

echo "Load tests complete!"
```

**Performance Benchmarks:**

| Metric | Target | Measured |
|--------|--------|----------|
| Concurrent Connections | 5,000 | TBD |
| P50 Latency | < 50ms | TBD |
| P95 Latency | < 150ms | TBD |
| P99 Latency | < 300ms | TBD |
| Events/Second | 50+ | TBD |
| Memory per Connection | < 5KB | TBD |
| CPU Usage (avg) | < 60% | TBD |

**Acceptance Criteria:**
- [ ] 5,000 concurrent connections supported
- [ ] P95 latency < 150ms
- [ ] 50+ events/second processing
- [ ] Memory usage < 25MB for 5K connections
- [ ] Load test suite automated

---

### Frontend Integration (2 days)

**Files to Create:**
- `assets/src/hooks/useWebSocket.ts`
- `assets/src/hooks/usePresence.ts`
- `assets/src/hooks/useActivityFeed.ts`
- `assets/src/services/websocket.ts`
- `assets/src/components/PresenceIndicator.tsx`

**Implementation Steps:**

1. **WebSocket Connection Manager:**

```typescript
// assets/src/services/websocket.ts
import { Socket } from 'phoenix';

class WebSocketManager {
  private socket: Socket | null = null;
  private channels: Map<string, any> = new Map();

  connect(token: string) {
    this.socket = new Socket('/socket', {
      params: { token },
      heartbeatIntervalMs: 30000,
      reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000][tries - 1] || 10000,
    });

    this.socket.connect();

    this.socket.onError(() => console.error('WebSocket error'));
    this.socket.onClose(() => console.log('WebSocket closed'));
  }

  joinChannel(topic: string, onJoin?: (response: any) => void) {
    if (!this.socket) throw new Error('Socket not connected');

    const channel = this.socket.channel(topic, {});

    channel
      .join()
      .receive('ok', (response) => {
        console.log(`Joined ${topic}`, response);
        onJoin?.(response);
      })
      .receive('error', (response) => {
        console.error(`Failed to join ${topic}`, response);
      });

    this.channels.set(topic, channel);
    return channel;
  }

  leaveChannel(topic: string) {
    const channel = this.channels.get(topic);
    if (channel) {
      channel.leave();
      this.channels.delete(topic);
    }
  }

  disconnect() {
    this.channels.forEach((channel) => channel.leave());
    this.channels.clear();
    this.socket?.disconnect();
  }
}

export const websocketManager = new WebSocketManager();
```

2. **React Hook for Presence:**

```typescript
// assets/src/hooks/usePresence.ts
import { useEffect, useState } from 'react';
import { websocketManager } from '../services/websocket';
import { Presence } from 'phoenix';

interface PresenceData {
  userId: string;
  username: string;
  avatarUrl?: string;
  status: string;
  onlineAt: string;
}

export function usePresence(topic: string = 'presence:lobby') {
  const [presences, setPresences] = useState<Map<string, PresenceData>>(new Map());
  const [onlineCount, setOnlineCount] = useState(0);

  useEffect(() => {
    const channel = websocketManager.joinChannel(topic, (response) => {
      const presence = new Presence(channel);

      presence.onSync(() => {
        const users = new Map<string, PresenceData>();

        presence.list((id, { metas }) => {
          const meta = metas[0];
          users.set(id, {
            userId: meta.user_id,
            username: meta.username,
            avatarUrl: meta.avatar_url,
            status: meta.status,
            onlineAt: meta.online_at,
          });
        });

        setPresences(users);
        setOnlineCount(users.size);
      });
    });

    return () => {
      websocketManager.leaveChannel(topic);
    };
  }, [topic]);

  return { presences, onlineCount };
}
```

3. **Presence Indicator Component:**

```typescript
// assets/src/components/PresenceIndicator.tsx
import React from 'react';
import { usePresence } from '../hooks/usePresence';

export function PresenceIndicator() {
  const { presences, onlineCount } = usePresence('presence:lobby');

  return (
    <div className="flex items-center gap-2 rounded-lg bg-slate-100 px-4 py-2">
      <div className="h-2 w-2 rounded-full bg-green-500 animate-pulse" />
      <span className="text-sm font-medium text-slate-700">
        {onlineCount} {onlineCount === 1 ? 'student' : 'students'} online
      </span>

      {onlineCount > 0 && (
        <div className="flex -space-x-2">
          {Array.from(presences.values()).slice(0, 3).map((user) => (
            <img
              key={user.userId}
              src={user.avatarUrl || '/default-avatar.png'}
              alt={user.username}
              className="h-6 w-6 rounded-full border-2 border-white"
              title={user.username}
            />
          ))}
          {onlineCount > 3 && (
            <div className="flex h-6 w-6 items-center justify-center rounded-full border-2 border-white bg-slate-300 text-xs font-semibold text-slate-700">
              +{onlineCount - 3}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

**Testing Strategy:**

```typescript
// assets/src/hooks/__tests__/usePresence.test.ts
import { renderHook, waitFor } from '@testing-library/react';
import { usePresence } from '../usePresence';
import { websocketManager } from '../../services/websocket';

jest.mock('../../services/websocket');

describe('usePresence', () => {
  it('connects to presence channel and tracks users', async () => {
    const mockChannel = {
      on: jest.fn(),
      push: jest.fn(),
    };

    (websocketManager.joinChannel as jest.Mock).mockReturnValue(mockChannel);

    const { result } = renderHook(() => usePresence());

    await waitFor(() => {
      expect(websocketManager.joinChannel).toHaveBeenCalledWith('presence:lobby', expect.any(Function));
    });

    expect(result.current.onlineCount).toBe(0);
  });
});
```

**Acceptance Criteria:**
- [ ] WebSocket connection manager implemented
- [ ] Presence hook with real-time updates
- [ ] Activity feed hook functional
- [ ] Frontend components styled with Tailwind
- [ ] TypeScript types for all WebSocket messages

---

### Task #1 Summary

**Total Effort:** 10 days
**Developers:** 2 backend + 1 frontend
**Test Coverage Target:** >90%
**Performance Targets:**
- 5,000 concurrent connections
- P95 latency < 150ms
- 50+ events/second

**Dependencies Unlocked:**
- Task #2: Global & Subject-Specific Presence
- Task #3: Real-Time Activity Feed
- Task #4: Mini-Leaderboards
- Task #5: Study Buddy Nudge System
- Task #6: Buddy Challenge Viral Loop
- Task #7: Results Rally Viral Loop
- Task #9: Streak Rescue Mechanism

---

## Task #2: Implement Global and Subject-Specific Presence

**Priority:** High | **Complexity:** 7/10 | **Duration:** 7 days | **Dependencies:** Task #1

### Overview

Build rich presence tracking that shows who's online globally and within specific subjects, with metadata about what users are currently doing (studying, taking quiz, browsing).

### Database Schema

**Migration:**

```elixir
# priv/repo/migrations/20250104000001_create_presence_sessions.exs
defmodule ViralEngine.Repo.Migrations.CreatePresenceSessions do
  use Ecto.Migration

  def change do
    create table(:presence_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all)
      add :session_id, :string, null: false
      add :status, :string, default: "online"
      add :current_activity, :string
      add :metadata, :map, default: %{}
      add :last_seen_at, :utc_datetime, null: false
      add :connected_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:presence_sessions, [:user_id])
    create index(:presence_sessions, [:subject_id])
    create index(:presence_sessions, [:last_seen_at])
    create unique_index(:presence_sessions, [:session_id])
  end
end
```

### Subtasks

#### 2.1: Enhanced Presence Context (2 days)

**Files to Create:**
- `lib/viral_engine/presence_tracking.ex`
- `lib/viral_engine/presence_tracking/session.ex`
- `test/viral_engine/presence_tracking_test.exs`

**Implementation:**

```elixir
# lib/viral_engine/presence_tracking/session.ex
defmodule ViralEngine.PresenceTracking.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presence_sessions" do
    field :session_id, :string
    field :status, :string, default: "online"
    field :current_activity, :string
    field :metadata, :map, default: %{}
    field :last_seen_at, :utc_datetime
    field :connected_at, :utc_datetime

    belongs_to :user, ViralEngine.Accounts.User
    belongs_to :subject, ViralEngine.Content.Subject

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :subject_id, :session_id, :status, :current_activity, :metadata, :last_seen_at, :connected_at])
    |> validate_required([:user_id, :session_id, :last_seen_at, :connected_at])
    |> validate_inclusion(:status, ["online", "away", "studying", "in_quiz"])
    |> unique_constraint(:session_id)
  end
end
```

```elixir
# lib/viral_engine/presence_tracking.ex
defmodule ViralEngine.PresenceTracking do
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.PresenceTracking.Session

  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(session_id, attrs) do
    get_session!(session_id)
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def get_online_users(subject_id \\ nil) do
    cutoff = DateTime.add(DateTime.utc_now(), -5, :minute)

    query =
      from s in Session,
        where: s.last_seen_at > ^cutoff,
        preload: [:user]

    query =
      if subject_id do
        where(query, [s], s.subject_id == ^subject_id)
      else
        query
      end

    Repo.all(query)
  end

  def cleanup_stale_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -10, :minute)

    from(s in Session, where: s.last_seen_at < ^cutoff)
    |> Repo.delete_all()
  end
end
```

**Acceptance Criteria:**
- [ ] Session tracking persisted to database
- [ ] Stale session cleanup job configured
- [ ] Subject-specific presence queries optimized
- [ ] Test coverage > 90%

---

#### 2.2: Presence LiveView Components (3 days)

**Files to Create:**
- `lib/viral_engine_web/live/presence_live.ex`
- `lib/viral_engine_web/live/presence_live.html.heex`
- `lib/viral_engine_web/components/presence_components.ex`

**Implementation:**

```elixir
# lib/viral_engine_web/live/presence_live.ex
defmodule ViralEngineWeb.PresenceLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Presence, PresenceTracking}

  @impl true
  def mount(%{"subject_id" => subject_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subject:#{subject_id}")
    end

    {:ok,
     socket
     |> assign(:subject_id, subject_id)
     |> assign(:online_users, [])
     |> load_presence()}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, load_presence(socket)}
  end

  defp load_presence(socket) do
    subject_id = socket.assigns.subject_id
    online_users = PresenceTracking.get_online_users(subject_id)

    assign(socket, :online_users, online_users)
  end
end
```

**Acceptance Criteria:**
- [ ] LiveView updates in real-time
- [ ] Subject-specific presence displayed
- [ ] User activity indicators shown
- [ ] Performance optimized for 100+ users

---

#### 2.3: Presence REST API (2 days)

**Files to Create:**
- `lib/viral_engine_web/controllers/presence_controller.ex`
- `lib/viral_engine_web/views/presence_view.ex`

**Implementation:**

```elixir
# lib/viral_engine_web/controllers/presence_controller.ex
defmodule ViralEngineWeb.PresenceController do
  use ViralEngineWeb, :controller
  alias ViralEngine.PresenceTracking

  def index(conn, %{"subject_id" => subject_id}) do
    online_users = PresenceTracking.get_online_users(subject_id)
    render(conn, "index.json", users: online_users)
  end

  def index(conn, _params) do
    online_users = PresenceTracking.get_online_users()
    render(conn, "index.json", users: online_users)
  end

  def update_status(conn, %{"status" => status}) do
    user_id = conn.assigns.current_user.id
    session_id = get_session_id(conn)

    case PresenceTracking.update_session(session_id, %{status: status}) do
      {:ok, session} ->
        render(conn, "show.json", session: session)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end
end
```

**Acceptance Criteria:**
- [ ] REST API endpoints functional
- [ ] JSON serialization optimized
- [ ] Authentication required
- [ ] Rate limiting configured

---

### Task #2 Summary

**Total Effort:** 7 days
**Test Coverage Target:** >90%
**Performance:** Sub-100ms API response times

---

## Task #3: Build Real-Time Activity Feed

**Priority:** Medium | **Complexity:** 6/10 | **Duration:** 6 days | **Dependencies:** Task #1

### Overview

Create a real-time activity feed system that broadcasts user achievements, milestones, and social interactions to drive engagement and FOMO.

### Database Schema

**Migration:**

```elixir
# priv/repo/migrations/20250105000001_create_activity_events.exs
defmodule ViralEngine.Repo.Migrations.CreateActivityEvents do
  use Ecto.Migration

  def change do
    create table(:activity_events) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all)
      add :event_type, :string, null: false
      add :data, :map, default: %{}
      add :visibility, :string, default: "public"
      add :reactions_count, :integer, default: 0

      timestamps()
    end

    create index(:activity_events, [:user_id])
    create index(:activity_events, [:subject_id])
    create index(:activity_events, [:event_type])
    create index(:activity_events, [:inserted_at])

    create table(:activity_reactions) do
      add :activity_event_id, references(:activity_events, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reaction, :string, null: false

      timestamps()
    end

    create unique_index(:activity_reactions, [:activity_event_id, :user_id])
  end
end
```

### Event Types

- `achievement_unlocked` - User unlocked a badge/achievement
- `streak_milestone` - User reached streak milestone (7, 30, 100 days)
- `high_score` - User achieved new high score in subject
- `quiz_completed` - User completed a quiz
- `level_up` - User leveled up in a subject
- `friend_joined` - Friend accepted invitation
- `challenge_won` - User won a peer challenge
- `leaderboard_rank` - User entered top 10 in subject

### Subtasks

#### 3.1: Activity Event System (2 days)

**Files to Create:**
- `lib/viral_engine/activities.ex`
- `lib/viral_engine/activities/event.ex`
- `lib/viral_engine/activities/reaction.ex`

**Implementation:**

```elixir
# lib/viral_engine/activities.ex
defmodule ViralEngine.Activities do
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.Activities.{Event, Reaction}
  alias ViralEngine.PubSubHelper

  def create_event(attrs) do
    with {:ok, event} <- %Event{} |> Event.changeset(attrs) |> Repo.insert() do
      # Broadcast to activity channels
      PubSubHelper.broadcast_activity(event.event_type, event)

      if event.subject_id do
        PubSubHelper.broadcast_subject_activity(event.subject_id, event.event_type, event)
      end

      {:ok, event}
    end
  end

  def list_recent_activities(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in Event,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      preload: [:user, :subject]
    )
    |> Repo.all()
  end

  def list_subject_activities(subject_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in Event,
      where: e.subject_id == ^subject_id,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def add_reaction(activity_id, user_id, reaction) do
    %Reaction{}
    |> Reaction.changeset(%{
      activity_event_id: activity_id,
      user_id: user_id,
      reaction: reaction
    })
    |> Repo.insert()
    |> case do
      {:ok, reaction} ->
        increment_reactions_count(activity_id)
        {:ok, reaction}
      error ->
        error
    end
  end

  defp increment_reactions_count(activity_id) do
    from(e in Event, where: e.id == ^activity_id)
    |> Repo.update_all(inc: [reactions_count: 1])
  end
end
```

**Acceptance Criteria:**
- [ ] Event creation with broadcasting
- [ ] Reaction system implemented
- [ ] Pagination for activity lists
- [ ] Test coverage > 90%

---

#### 3.2: Activity Feed LiveView (2 days)

**Files to Create:**
- `lib/viral_engine_web/live/activity_feed_live.ex`
- `lib/viral_engine_web/live/activity_feed_live.html.heex`
- `lib/viral_engine_web/components/activity_item.ex`

**Implementation:**

```elixir
# lib/viral_engine_web/live/activity_feed_live.ex
defmodule ViralEngineWeb.ActivityFeedLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.Activities

  @impl true
  def mount(params, _session, socket) do
    subject_id = Map.get(params, "subject_id")

    if connected?(socket) do
      topic = if subject_id, do: "activity:subject:#{subject_id}", else: "activity:global"
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, topic)
    end

    activities = load_activities(subject_id)

    {:ok,
     socket
     |> assign(:subject_id, subject_id)
     |> assign(:activities, activities)
     |> assign(:page, 1)}
  end

  @impl true
  def handle_info({:activity, _event_type, event}, socket) do
    activities = [event | socket.assigns.activities] |> Enum.take(50)
    {:noreply, assign(socket, :activities, activities)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    page = socket.assigns.page + 1
    new_activities = load_activities(socket.assigns.subject_id, page: page)

    {:noreply,
     socket
     |> assign(:activities, socket.assigns.activities ++ new_activities)
     |> assign(:page, page)}
  end

  defp load_activities(nil, opts \\ []) do
    Activities.list_recent_activities(opts)
  end

  defp load_activities(subject_id, opts) do
    Activities.list_subject_activities(subject_id, opts)
  end
end
```

**Acceptance Criteria:**
- [ ] Real-time activity updates
- [ ] Infinite scroll pagination
- [ ] Filtering by event type
- [ ] Performance optimized

---

#### 3.3: Frontend Activity Feed (2 days)

**Files to Create:**
- `assets/src/components/ActivityFeed.tsx`
- `assets/src/components/ActivityItem.tsx`
- `assets/src/hooks/useActivityFeed.ts`

**Implementation:**

```typescript
// assets/src/components/ActivityFeed.tsx
import React, { useEffect, useState } from 'react';
import { useActivityFeed } from '../hooks/useActivityFeed';
import { ActivityItem } from './ActivityItem';

interface Activity {
  id: string;
  userId: string;
  eventType: string;
  data: Record<string, any>;
  timestamp: string;
  reactionsCount: number;
}

export function ActivityFeed({ subjectId }: { subjectId?: string }) {
  const { activities, loading } = useActivityFeed(subjectId);

  if (loading) {
    return <div className="animate-pulse">Loading activities...</div>;
  }

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold text-slate-900">Recent Activity</h2>

      <div className="space-y-2">
        {activities.map((activity) => (
          <ActivityItem key={activity.id} activity={activity} />
        ))}
      </div>

      {activities.length === 0 && (
        <div className="rounded-lg border-2 border-dashed border-slate-300 p-8 text-center">
          <p className="text-slate-500">No recent activity</p>
        </div>
      )}
    </div>
  );
}
```

**Acceptance Criteria:**
- [ ] Real-time feed updates
- [ ] Activity reactions implemented
- [ ] Engagement tracking
- [ ] TypeScript fully typed

---

### Task #3 Summary

**Total Effort:** 6 days
**Test Coverage Target:** >90%
**Performance:** Handle 100+ activities/minute

---

## Task #4: Develop Mini-Leaderboards for Subjects

**Priority:** Medium | **Complexity:** 6/10 | **Duration:** 6 days | **Dependencies:** Task #1

### Overview

Build competitive mini-leaderboards for each subject with daily/weekly/all-time rankings to drive engagement through social comparison.

### Database Schema

**Migration:**

```elixir
# priv/repo/migrations/20250106000001_create_leaderboard_entries.exs
defmodule ViralEngine.Repo.Migrations.CreateLeaderboardEntries do
  use Ecto.Migration

  def change do
    create table(:leaderboard_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all), null: false
      add :score, :integer, null: false
      add :rank, :integer
      add :period, :string, null: false # "daily", "weekly", "all_time"
      add :period_start, :date, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:leaderboard_entries, [:subject_id, :period, :rank])
    create index(:leaderboard_entries, [:user_id, :subject_id])
    create unique_index(:leaderboard_entries, [:user_id, :subject_id, :period, :period_start])
  end
end
```

### Subtasks

#### 4.1: Leaderboard Calculation Engine (2 days)

**Files to Create:**
- `lib/viral_engine/leaderboards.ex`
- `lib/viral_engine/leaderboards/entry.ex`
- `lib/viral_engine/leaderboards/calculator.ex`

**Implementation:**

```elixir
# lib/viral_engine/leaderboards/calculator.ex
defmodule ViralEngine.Leaderboards.Calculator do
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.Leaderboards.Entry

  def recalculate_rankings(subject_id, period) do
    period_start = get_period_start(period)

    # Get all entries for period
    entries =
      from(e in Entry,
        where: e.subject_id == ^subject_id,
        where: e.period == ^period,
        where: e.period_start == ^period_start,
        order_by: [desc: e.score],
        select: e
      )
      |> Repo.all()

    # Update ranks
    entries
    |> Enum.with_index(1)
    |> Enum.each(fn {entry, rank} ->
      Entry.changeset(entry, %{rank: rank})
      |> Repo.update()
    end)

    # Broadcast top 10 update
    top_10 = Enum.take(entries, 10)
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "leaderboard:#{subject_id}",
      {:leaderboard_update, %{period: period, entries: top_10}}
    )
  end

  defp get_period_start("daily"), do: Date.utc_today()
  defp get_period_start("weekly") do
    today = Date.utc_today()
    Date.add(today, -Date.day_of_week(today) + 1)
  end
  defp get_period_start("all_time"), do: ~D[2025-01-01]
end
```

**Acceptance Criteria:**
- [ ] Ranking calculation optimized
- [ ] Background job for recalculation
- [ ] Real-time rank updates
- [ ] Test coverage > 90%

---

#### 4.2: Leaderboard LiveView (2 days)

**Files to Create:**
- `lib/viral_engine_web/live/leaderboard_live.ex`
- `lib/viral_engine_web/live/leaderboard_live.html.heex`

**Acceptance Criteria:**
- [ ] LiveView with period tabs
- [ ] Real-time rank updates
- [ ] User highlighting
- [ ] Mobile responsive

---

#### 4.3: Frontend Leaderboard Components (2 days)

**Files to Create:**
- `assets/src/components/Leaderboard.tsx`
- `assets/src/components/LeaderboardEntry.tsx`

**Acceptance Criteria:**
- [ ] Animated rank changes
- [ ] Period switching
- [ ] User profile links
- [ ] TypeScript typed

---

### Task #4 Summary

**Total Effort:** 6 days
**Test Coverage Target:** >90%
**Performance:** <100ms query times

---

## Task #5: Add Study Buddy Nudge Feature

**Priority:** Medium | **Complexity:** 5/10 | **Duration:** 5 days | **Dependencies:** Tasks #1, #2

### Overview

Implement a "nudge" system that detects when friends are online studying and prompts users to join them, creating FOMO and increasing session frequency.

### Database Schema

**Migration:**

```elixir
# priv/repo/migrations/20250107000001_create_nudges.exs
defmodule ViralEngine.Repo.Migrations.CreateNudges do
  use Ecto.Migration

  def change do
    create table(:nudges) do
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, on_delete: :delete_all), null: false
      add :nudge_type, :string, null: false # "friend_online", "challenge", "streak_rescue"
      add :subject_id, references(:subjects, on_delete: :nilify_all)
      add :status, :string, default: "pending" # "pending", "accepted", "ignored", "expired"
      add :metadata, :map, default: %{}
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:nudges, [:recipient_id, :status])
    create index(:nudges, [:sender_id])
    create index(:nudges, [:expires_at])
  end
end
```

### Subtasks

#### 5.1: Nudge Detection System (2 days)

**Files to Create:**
- `lib/viral_engine/nudges.ex`
- `lib/viral_engine/nudges/detector.ex`
- `lib/viral_engine/workers/nudge_worker.ex`

**Implementation:**

```elixir
# lib/viral_engine/nudges/detector.ex
defmodule ViralEngine.Nudges.Detector do
  alias ViralEngine.{Accounts, PresenceTracking, Nudges}

  def detect_and_send_nudges(user_id) do
    user = Accounts.get_user!(user_id)
    friends = Accounts.list_friends(user_id)
    online_friends = Enum.filter(friends, &is_online?/1)

    Enum.each(online_friends, fn friend ->
      if should_nudge?(user, friend) do
        Nudges.create_nudge(%{
          sender_id: friend.id,
          recipient_id: user.id,
          nudge_type: "friend_online",
          subject_id: get_current_subject(friend.id),
          expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
        })
      end
    end)
  end

  defp is_online?(user) do
    PresenceTracking.get_online_users()
    |> Enum.any?(fn session -> session.user_id == user.id end)
  end

  defp should_nudge?(user, friend) do
    # Don't nudge if already nudged in last hour
    recent_nudge = Nudges.get_recent_nudge(friend.id, user.id, hours: 1)

    # Don't nudge if user is already online
    user_online = is_online?(user)

    is_nil(recent_nudge) && !user_online
  end
end
```

**Acceptance Criteria:**
- [ ] Nudge detection logic implemented
- [ ] Oban worker configured
- [ ] Rate limiting per user
- [ ] Test coverage > 90%

---

#### 5.2: Nudge Notification UI (2 days)

**Files to Create:**
- `lib/viral_engine_web/live/nudge_center_live.ex`
- `assets/src/components/NudgeNotification.tsx`

**Acceptance Criteria:**
- [ ] Real-time nudge notifications
- [ ] Accept/ignore actions
- [ ] Notification preferences
- [ ] Toast notifications

---

#### 5.3: Background Jobs (1 day)

**Files to Create:**
- `lib/viral_engine/workers/nudge_worker.ex`
- `lib/viral_engine/workers/nudge_cleanup_worker.ex`

**Acceptance Criteria:**
- [ ] Oban job configured
- [ ] Expired nudge cleanup
- [ ] Job monitoring
- [ ] Error handling

---

### Task #5 Summary

**Total Effort:** 5 days
**Test Coverage Target:** >90%
**Performance:** <50ms nudge delivery

---

## Sprint Timeline & Resource Allocation

### Gantt Chart

```
Week 1:
  Task #1 (Days 1-5): Backend infrastructure, channels, PubSub

Week 2:
  Task #1 (Days 6-10): Frontend integration, load testing
  Task #2 (Days 8-10): Presence backend starts (parallel)

Week 3:
  Task #2 (Days 11-14): Presence LiveView, API
  Task #3 (Days 13-15): Activity feed backend (parallel)

Week 4:
  Task #3 (Days 16-18): Activity feed frontend
  Task #4 (Days 16-21): Leaderboards (parallel)

Week 5:
  Task #5 (Days 22-26): Nudge system
  Testing & Polish (Days 27-34): Integration testing, performance tuning
```

### Team Allocation

**Backend Developer #1:**
- Task #1.1-1.2 (Phoenix Channels, PubSub)
- Task #2.1 (Presence context)
- Task #4.1 (Leaderboard calculations)

**Backend Developer #2:**
- Task #1.3 (Activity channels)
- Task #3.1 (Activity event system)
- Task #5.1 (Nudge detection)

**Frontend Developer:**
- Task #1.4 (Frontend WebSocket integration)
- Task #2.3 (Presence UI)
- Task #3.3 (Activity feed UI)
- Task #4.3 (Leaderboard UI)
- Task #5.2 (Nudge UI)

---

## Testing Strategy

### Unit Tests

- **Target Coverage:** >90%
- **Framework:** ExUnit (backend), Vitest (frontend)
- **Focus Areas:**
  - Business logic in contexts
  - Channel join/leave/broadcast logic
  - Presence tracking calculations
  - Leaderboard ranking algorithms

### Integration Tests

- **Framework:** ExUnit with Ecto.Sandbox
- **Focus Areas:**
  - Channel communication flows
  - PubSub message delivery
  - Database transactions
  - API endpoint responses

### Load Tests

- **Framework:** Custom scripts + Grafana
- **Scenarios:**
  - 5,000 concurrent WebSocket connections
  - 50 events/second broadcasting
  - 1,000 presence updates/second
  - 100 leaderboard queries/second

### Frontend Tests

- **Framework:** Vitest + React Testing Library
- **Focus Areas:**
  - Component rendering
  - WebSocket connection handling
  - Real-time UI updates
  - User interactions

---

## Performance Requirements

| Metric | Target | Monitoring |
|--------|--------|------------|
| WebSocket Latency (P95) | <150ms | AppSignal |
| API Response Time (P95) | <100ms | AppSignal |
| Concurrent Connections | 5,000+ | Phoenix LiveDashboard |
| Events/Second | 50+ | Custom metrics |
| Database Query Time (P95) | <50ms | Ecto telemetry |
| Memory per Connection | <5KB | :observer |
| Frontend Bundle Size | <500KB | Vite analyzer |

---

## Risk Assessment

### High Risks

1. **WebSocket Connection Limits**
   - **Mitigation:** Load testing early, Redis scaling, connection pooling

2. **Database Performance Under Load**
   - **Mitigation:** Proper indexing, materialized views, read replicas

3. **Real-time Update Storms**
   - **Mitigation:** Message throttling, batching, debouncing

### Medium Risks

4. **Frontend State Management Complexity**
   - **Mitigation:** Use proven patterns (Zustand), TypeScript strict mode

5. **PubSub Message Ordering**
   - **Mitigation:** Timestamp-based ordering, idempotent handlers

6. **Presence Tracking Accuracy**
   - **Mitigation:** Heartbeat monitoring, cleanup jobs

### Low Risks

7. **COPPA/FERPA Compliance**
   - **Mitigation:** Legal review, privacy-by-design, parental controls

8. **Leaderboard Gaming**
   - **Mitigation:** Score validation, rate limiting, anomaly detection

---

## Success Metrics

### Technical KPIs

- [ ] 99.9% WebSocket uptime
- [ ] <150ms P95 latency
- [ ] 5,000+ concurrent connections
- [ ] >90% test coverage
- [ ] Zero P0/P1 security vulnerabilities

### Product KPIs

- [ ] 30% increase in daily active users
- [ ] 50% increase in session frequency
- [ ] 20% increase in peer invitations
- [ ] 15% increase in quiz completion rate
- [ ] 10% increase in viral coefficient

### Engagement KPIs

- [ ] 40% of users interact with activity feed daily
- [ ] 25% of users check leaderboards daily
- [ ] 15% of users respond to nudges positively
- [ ] 60% of online users visible in presence

---

## Getting Started

### Prerequisites

```bash
# Install dependencies
mix deps.get
npm install --prefix assets

# Set up database
mix ecto.create
mix ecto.migrate

# Start Redis
docker run -d --name redis -p 6379:6379 redis:7

# Configure environment
cp .env.example .env
# Edit .env with REDIS_URL, DATABASE_URL, etc.
```

### Development Workflow

```bash
# Start Phoenix server
mix phx.server

# Run tests
mix test

# Run load tests
mix test test/load/

# Frontend development
cd assets && npm run dev

# Type checking
cd assets && npm run type-check
```

### Deployment

```bash
# Build release
MIX_ENV=prod mix release

# Deploy to Fly.io
fly deploy

# Monitor
fly logs
fly status
```

---

## Appendix

### External Dependencies

- **Redis** - PubSub, caching
- **PostgreSQL** - Primary database
- **Oban** - Background job processing
- **AppSignal** - Monitoring & APM
- **Fly.io** - Hosting infrastructure

### API Documentation

API docs will be generated using:
- **Backend:** ExDoc + OpenAPI specs
- **Frontend:** TypeDoc
- **WebSocket:** Custom message format documentation

### Security Considerations

- [ ] JWT token expiration (24 hours)
- [ ] WebSocket rate limiting (100 messages/minute)
- [ ] SQL injection prevention (Ecto parameterized queries)
- [ ] XSS prevention (Phoenix.HTML escaping)
- [ ] CSRF protection (Phoenix tokens)
- [ ] Privacy controls (COPPA/FERPA compliant)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Next Review:** 2025-11-11
**Owner:** Development Team
