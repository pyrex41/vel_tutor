defmodule ViralEngine.Jobs.ResetHourlyLimitsTest do
  use ViralEngine.DataCase, async: true
  import ExUnit.CaptureLog

  alias ViralEngine.{Jobs.ResetHourlyLimits, RateLimitContext, OrganizationContext, Repo, User}

  setup do
    # Set up tenant context
    tenant_id = Ecto.UUID.generate()
    OrganizationContext.set_current_tenant_id(tenant_id)

    # Create a user with rate limits
    {:ok, user} =
      Repo.insert(%User{
        email: "test@example.com",
        name: "Test User"
      })

    # Create rate limits with some usage
    {:ok, rate_limit} =
      RateLimitContext.upsert_rate_limit(%{
        user_id: user.id,
        tasks_per_hour: 10,
        concurrent_tasks: 2
      })

    # Manually increment counters to simulate usage
    {:ok, _} = RateLimitContext.increment_hourly_count(user.id)
    {:ok, _} = RateLimitContext.increment_hourly_count(user.id)
    {:ok, _} = RateLimitContext.increment_concurrent_count(user.id)

    %{rate_limit: rate_limit, user: user, tenant_id: tenant_id}
  end

  describe "perform/1" do
    test "resets hourly counters for all rate limits", %{rate_limit: rate_limit} do
      # Verify counters are set
      assert rate_limit.current_hourly_count == 2
      assert rate_limit.current_concurrent_count == 1

      # Run the job
      assert {:ok, count} = ResetHourlyLimits.perform(%{})

      # Should have reset 1 rate limit
      assert count == 1

      # Verify counters are reset
      updated_limit = RateLimitContext.get_rate_limit(rate_limit.user_id)
      assert updated_limit.current_hourly_count == 0
      # Concurrent count should not be reset by this job
      assert updated_limit.current_concurrent_count == 1
    end

    test "handles empty rate limits table" do
      # Clear all rate limits
      for rate_limit <- RateLimitContext.list_rate_limits() do
        RateLimitContext.delete_rate_limit(rate_limit.id)
      end

      # Run the job
      assert {:ok, 0} = ResetHourlyLimits.perform(%{})
    end

    test "logs the number of reset rate limits", %{rate_limit: rate_limit} do
      # Capture logs
      log =
        capture_log(fn ->
          ResetHourlyLimits.perform(%{})
        end)

      assert log =~ "Reset hourly counters for 1 rate limits"
    end

    test "only resets hourly counters, not concurrent counters", %{rate_limit: rate_limit} do
      # Run the job
      ResetHourlyLimits.perform(%{})

      # Check that only hourly counter is reset
      updated_limit = RateLimitContext.get_rate_limit(rate_limit.user_id)
      assert updated_limit.current_hourly_count == 0
      # Should remain unchanged
      assert updated_limit.current_concurrent_count == 1
    end
  end
end
