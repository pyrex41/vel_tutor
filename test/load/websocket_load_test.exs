defmodule ViralEngine.LoadTest.WebSocketTest do
  use ExUnit.Case
  alias Phoenix.ChannelsClient

  @target_connections 5_000
  @events_per_second 50
  @test_duration_seconds 60

  test "handles #{@target_connections} concurrent WebSocket connections" do
    # Spawn concurrent connections
    tasks =
      for i <- 1..@target_connections do
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

    {:ok, socket} =
      ChannelsClient.connect(
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

  defp generate_token(user_id) do
    # Generate a test token for the user
    # In a real implementation, this would create a proper JWT
    "test_token_#{user_id}"
  end
end
