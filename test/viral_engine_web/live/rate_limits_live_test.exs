defmodule ViralEngineWeb.RateLimitsLiveTest do
  use ViralEngineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ViralEngine.{RateLimitContext, OrganizationContext, RBACContext, Repo, User}

  setup do
    # Set up tenant context
    tenant_id = Ecto.UUID.generate()
    OrganizationContext.set_current_tenant_id(tenant_id)

    # Create organization
    {:ok, org} = OrganizationContext.create_organization(%{name: "Test Org"})

    # Create admin user
    {:ok, admin_user} =
      Repo.insert(%User{
        email: "admin@example.com",
        name: "Admin User",
        organization_id: org.id
      })

    # Assign admin role
    {:ok, admin_role} = RBACContext.get_role_by_name("admin")
    RBACContext.assign_role(admin_user.id, admin_role.id, org.id)

    # Create some rate limits
    {:ok, _user_limit} =
      RateLimitContext.upsert_rate_limit(%{
        user_id: admin_user.id,
        tasks_per_hour: 50,
        concurrent_tasks: 5
      })

    {:ok, _org_limit} =
      RateLimitContext.upsert_rate_limit(%{
        organization_id: org.id,
        tasks_per_hour: 200,
        concurrent_tasks: 20
      })

    %{
      org: org,
      admin_user: admin_user,
      tenant_id: tenant_id
    }
  end

  describe "mount/3" do
    test "mounts successfully for admin user", %{conn: conn, admin_user: admin_user, org: org} do
      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, _view, html} = live(conn, "/dashboard/rate-limits", session: session)

      assert html =~ "Rate Limits Dashboard"
      assert html =~ "Refresh"
    end

    test "shows permission denied for non-admin user", %{conn: conn, org: org} do
      # Create regular user
      {:ok, regular_user} =
        Repo.insert(%User{
          email: "regular@example.com",
          name: "Regular User",
          organization_id: org.id
        })

      session = %{
        "current_user_id" => regular_user.id,
        "current_organization_id" => org.id
      }

      {:ok, _view, html} = live(conn, "/dashboard/rate-limits", session: session)

      assert html =~ "You don't have permission to view this dashboard"
    end
  end

  describe "handle_event/3" do
    test "refresh updates the rate limits list", %{conn: conn, admin_user: admin_user, org: org} do
      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, view, _html} = live(conn, "/dashboard/rate-limits", session: session)

      # Click refresh
      view |> element("button", "Refresh") |> render_click()

      # Should still show the dashboard (no errors)
      assert render(view) =~ "Rate Limits Dashboard"
    end

    test "reset_counters removes rate limit configuration", %{
      conn: conn,
      admin_user: admin_user,
      org: org
    } do
      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, view, _html} = live(conn, "/dashboard/rate-limits", session: session)

      # Get the rate limit ID from the context
      [rate_limit | _] = RateLimitContext.list_rate_limits()
      rate_limit_id = rate_limit.id

      # Click reset counters
      view
      |> element("button[phx-value-id='#{rate_limit_id}']", "Reset Counters")
      |> render_click()

      # Should show success message
      assert render(view) =~ "Rate limit counters reset successfully"
    end
  end

  describe "render/1" do
    test "displays rate limits table with data", %{conn: conn, admin_user: admin_user, org: org} do
      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, _view, html} = live(conn, "/dashboard/rate-limits", session: session)

      # Check table headers
      assert html =~ "Type"
      assert html =~ "Tasks/Hour"
      assert html =~ "Current Hourly"
      assert html =~ "Concurrent Tasks"
      assert html =~ "Current Concurrent"
      assert html =~ "Actions"

      # Check that data is displayed
      # tasks_per_hour for user
      assert html =~ "50"
      # tasks_per_hour for org
      assert html =~ "200"
    end

    test "shows 'No custom rate limits configured' when empty", %{
      conn: conn,
      admin_user: admin_user,
      org: org
    } do
      # Clear all rate limits
      for rate_limit <- RateLimitContext.list_rate_limits() do
        RateLimitContext.delete_rate_limit(rate_limit.id)
      end

      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, _view, html} = live(conn, "/dashboard/rate-limits", session: session)

      assert html =~ "No custom rate limits configured"
      assert html =~ "All users are using default limits"
    end

    test "highlights exceeded limits", %{conn: conn, admin_user: admin_user, org: org} do
      # Set low limit and exceed it
      {:ok, rate_limit} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: admin_user.id,
          tasks_per_hour: 1,
          concurrent_tasks: 5
        })

      # Manually set high current count
      {:ok, _} = RateLimitContext.increment_hourly_count(admin_user.id)

      session = %{
        "current_user_id" => admin_user.id,
        "current_organization_id" => org.id
      }

      {:ok, _view, html} = live(conn, "/dashboard/rate-limits", session: session)

      # Should show limit exceeded styling
      assert html =~ "limit-exceeded"
    end
  end
end
