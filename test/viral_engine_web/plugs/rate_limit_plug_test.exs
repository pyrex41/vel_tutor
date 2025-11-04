defmodule ViralEngineWeb.Plugs.RateLimitPlugTest do
  use ViralEngineWeb.ConnCase, async: true

  alias ViralEngineWeb.Plugs.RateLimitPlug
  alias ViralEngine.{RateLimitContext, OrganizationContext, Repo, User}

  setup do
    # Set up tenant context for tests
    tenant_id = Ecto.UUID.generate()
    OrganizationContext.set_current_tenant_id(tenant_id)

    # Create a test user
    {:ok, user} =
      Repo.insert(%User{
        email: "test@example.com",
        name: "Test User"
      })

    # Create default rate limits for the user
    {:ok, _rate_limit} =
      RateLimitContext.upsert_rate_limit(%{
        user_id: user.id,
        tasks_per_hour: 10,
        concurrent_tasks: 2
      })

    %{user: user, tenant_id: tenant_id}
  end

  describe "call/2" do
    test "allows request within hourly limits", %{user: user} do
      conn =
        build_conn(:post, "/api/tasks", %{})
        |> assign(:current_user_id, user.id)
        |> assign(:current_organization_id, nil)

      # First request should succeed
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status != 429
    end

    test "blocks request when hourly limit exceeded", %{user: user} do
      # Set very low limit for testing
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: user.id,
          tasks_per_hour: 1,
          concurrent_tasks: 2
        })

      conn =
        build_conn(:post, "/api/tasks", %{})
        |> assign(:current_user_id, user.id)
        |> assign(:current_organization_id, nil)

      # First request should succeed
      RateLimitPlug.call(conn, [])

      # Second request should be blocked
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status == 429
      assert result_conn.resp_body =~ "Too Many Requests"
      assert get_resp_header(result_conn, "retry-after") != []
    end

    test "blocks request when concurrent limit exceeded", %{user: user} do
      # Set low concurrent limit
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: user.id,
          tasks_per_hour: 100,
          concurrent_tasks: 1
        })

      conn =
        build_conn(:post, "/api/tasks", %{})
        |> assign(:current_user_id, user.id)
        |> assign(:current_organization_id, nil)

      # Increment concurrent count manually
      {:ok, _} = RateLimitContext.increment_concurrent_count(user.id)

      # Request should be blocked
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status == 429
    end

    test "calculates correct retry-after header", %{user: user} do
      # Set limit of 1 per hour
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: user.id,
          tasks_per_hour: 1,
          concurrent_tasks: 2
        })

      conn =
        build_conn(:post, "/api/tasks", %{})
        |> assign(:current_user_id, user.id)
        |> assign(:current_organization_id, nil)

      # Use up the hourly limit
      RateLimitPlug.call(conn, [])

      # Next request should be blocked with retry-after
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status == 429

      [retry_after] = get_resp_header(result_conn, "retry-after")
      retry_seconds = String.to_integer(retry_after)
      assert retry_seconds > 0
      # Should be within an hour
      assert retry_seconds <= 3600
    end

    test "uses organization limits when no user limits exist" do
      # Create organization
      {:ok, org} =
        ViralEngine.OrganizationContext.create_organization(%{
          name: "Test Org"
        })

      # Set org limits
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          organization_id: org.id,
          tasks_per_hour: 5,
          concurrent_tasks: 1
        })

      conn =
        build_conn(:post, "/api/tasks", %{})
        # User without limits
        |> assign(:current_user_id, Ecto.UUID.generate())
        |> assign(:current_organization_id, org.id)

      # Should use org limits
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status != 429
    end

    test "uses default limits when no custom limits exist" do
      conn =
        build_conn(:post, "/api/tasks", %{})
        # User without limits
        |> assign(:current_user_id, Ecto.UUID.generate())
        |> assign(:current_organization_id, nil)

      # Should use default limits (100/hour, 5 concurrent)
      result_conn = RateLimitPlug.call(conn, [])
      assert result_conn.status != 429
    end
  end
end
