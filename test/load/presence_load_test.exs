defmodule ViralEngine.LoadTest.PresenceTest do
  use ExUnit.Case
  alias Phoenix.ChannelsClient

  @concurrent_users 1_000
  @presence_updates_per_second 100
  @test_duration_seconds 30

  test "handles #{@concurrent_users} concurrent presence updates" do
    # Start multiple users
    users =
      for i <- 1..@concurrent_users do
        {:ok, socket} =
          ChannelsClient.connect(
            "ws://localhost:4000/socket/websocket",
            params: %{token: generate_token(i)}
          )

        {:ok, _reply, channel} = ChannelsClient.join(socket, "presence:lobby")
        {i, socket, channel}
      end

    # Simulate presence updates
    start_time = System.monotonic_time(:millisecond)

    tasks =
      for {user_id, socket, channel} <- users do
        Task.async(fn ->
          update_presence_multiple_times(socket, channel, user_id)
        end)
      end

    # Wait for all updates to complete
    results = Enum.map(tasks, &Task.await(&1, 60_000))
    end_time = System.monotonic_time(:millisecond)

    total_time = end_time - start_time
    # 5 updates per user
    total_updates = @concurrent_users * 5
    updates_per_second = total_updates / (total_time / 1000)

    IO.puts("Total time: #{total_time}ms")
    IO.puts("Total updates: #{total_updates}")
    IO.puts("Updates per second: #{updates_per_second}")

    # Assert performance requirements
    assert updates_per_second >= @presence_updates_per_second,
           "Presence updates per second below target: #{updates_per_second}"

    # Check for errors
    errors = Enum.filter(results, fn result -> result != :ok end)
    assert length(errors) == 0, "Presence updates had #{length(errors)} errors"
  end

  defp update_presence_multiple_times(socket, channel, user_id) do
    statuses = ["online", "studying", "away", "online", "studying"]

    Enum.each(statuses, fn status ->
      ChannelsClient.push(channel, "update_status", %{"status" => status})
      # Small delay between updates
      Process.sleep(100)
    end)

    :ok
  end

  defp generate_token(user_id) do
    "test_token_#{user_id}"
  end
end
