defmodule ViralEngineWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Plug middleware for enforcing rate limits on API requests.
  """

  import Plug.Conn
  require Logger
  alias ViralEngine.RateLimitContext

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract user and organization IDs from conn
    # This assumes authentication has already happened and user/org IDs are in assigns
    user_id = conn.assigns[:current_user_id]
    organization_id = conn.assigns[:current_organization_id]

    # Check hourly limit
    case RateLimitContext.increment_hourly_count(user_id, organization_id) do
      {:ok, _rate_limit} ->
        # Check concurrent limit
        case RateLimitContext.increment_concurrent_count(user_id, organization_id) do
          {:ok, _rate_limit} ->
            # Store decrement function in conn for cleanup after request
            conn
            |> assign(:rate_limit_cleanup, fn ->
              RateLimitContext.decrement_concurrent_count(user_id, organization_id)
            end)

          {:error, :concurrent_limit_exceeded} ->
            conn
            |> send_rate_limit_error(:concurrent_limit_exceeded)
            |> halt()
        end

      {:error, :hourly_limit_exceeded} ->
        conn
        |> send_rate_limit_error(:hourly_limit_exceeded)
        |> halt()
    end
  end

  # Function to be called after request completion to decrement concurrent count
  def cleanup_rate_limit(conn) do
    case conn.assigns[:rate_limit_cleanup] do
      nil -> :ok
      cleanup_fn -> cleanup_fn.()
    end
  end

  defp send_rate_limit_error(conn, limit_type) do
    rate_limit =
      RateLimitContext.get_rate_limit(
        conn.assigns[:current_user_id],
        conn.assigns[:current_organization_id]
      )

    {status_code, retry_after} =
      case limit_type do
        :hourly_limit_exceeded ->
          retry_seconds = calculate_retry_seconds_until_next_hour()
          {429, retry_seconds}

        :concurrent_limit_exceeded ->
          # For concurrent limits, suggest retrying in 30 seconds
          {429, 30}
      end

    conn
    |> put_resp_header("retry-after", to_string(retry_after))
    |> put_resp_header("x-ratelimit-limit", to_string(rate_limit.tasks_per_hour))
    |> put_resp_header(
      "x-ratelimit-remaining",
      to_string(max(0, rate_limit.tasks_per_hour - rate_limit.current_hourly_count))
    )
    |> put_resp_header("x-ratelimit-reset", to_string(calculate_next_hour_timestamp()))
    |> put_status(status_code)
    |> json(%{
      error: "rate_limit_exceeded",
      message: rate_limit_error_message(limit_type, rate_limit),
      retry_after: retry_after,
      limit: rate_limit.tasks_per_hour,
      remaining: max(0, rate_limit.tasks_per_hour - rate_limit.current_hourly_count),
      reset_at: DateTime.from_unix!(calculate_next_hour_timestamp())
    })
  end

  defp rate_limit_error_message(:hourly_limit_exceeded, rate_limit) do
    "Hourly rate limit exceeded. Limit: #{rate_limit.tasks_per_hour} requests per hour."
  end

  defp rate_limit_error_message(:concurrent_limit_exceeded, rate_limit) do
    "Concurrent request limit exceeded. Limit: #{rate_limit.concurrent_tasks} concurrent requests."
  end

  defp calculate_retry_seconds_until_next_hour do
    now = DateTime.utc_now()
    next_hour = %{now | minute: 0, second: 0, microsecond: {0, 0}}

    next_hour =
      if now.minute == 0 and now.second == 0,
        do: next_hour,
        else: DateTime.add(next_hour, 3600, :second)

    DateTime.diff(next_hour, now, :second)
  end

  defp calculate_next_hour_timestamp do
    now = DateTime.utc_now()
    next_hour = %{now | minute: 0, second: 0, microsecond: {0, 0}}

    next_hour =
      if now.minute == 0 and now.second == 0,
        do: next_hour,
        else: DateTime.add(next_hour, 3600, :second)

    DateTime.to_unix(next_hour)
  end

  # Helper function to send JSON response
  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end
end
