defmodule ViralEngine.Jobs.ResetHourlyLimits do
  @moduledoc """
  GenServer to periodically reset hourly rate limit counters at the start of each hour.
  """

  use GenServer
  require Logger
  alias ViralEngine.RateLimitContext

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Schedule the first reset
    schedule_next_reset()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:reset_hourly_limits, state) do
    # Reset hourly counters (always succeeds in current implementation)
    {:ok, count} = RateLimitContext.reset_hourly_counters()
    Logger.info("Successfully reset hourly counters for #{count} rate limits")

    # Schedule the next reset
    schedule_next_reset()
    {:noreply, state}
  end

  defp schedule_next_reset do
    # Calculate milliseconds until next hour
    now = DateTime.utc_now()
    next_hour = %{now | minute: 0, second: 0, microsecond: {0, 0}}

    next_hour =
      if now.minute == 0 and now.second == 0,
        do: next_hour,
        else: DateTime.add(next_hour, 3600, :second)

    milliseconds_until_next_hour = DateTime.diff(next_hour, now, :millisecond)

    # Schedule the reset
    Process.send_after(self(), :reset_hourly_limits, milliseconds_until_next_hour)
  end
end
