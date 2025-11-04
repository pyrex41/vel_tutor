defmodule ViralEngineWeb.UserControllerTest do
  use ViralEngineWeb.ConnCase, async: true

  alias ViralEngine.{RateLimitContext, OrganizationContext, RBACContext, Repo, User}

  setup do
    # Set up tenant context
    tenant_id = Ecto.UUID.generate()
    OrganizationContext.set_current_tenant_id(tenant_id)

    # Create organization
    {:ok, org} = OrganizationContext.create_organization(%{name: "Test Org"})

    # Create users
    {:ok, admin_user} =
      Repo.insert(%User{
        email: "admin@example.com",
        name: "Admin User",
        organization_id: org.id
      })

    {:ok, regular_user} =
      Repo.insert(%User{
        email: "user@example.com",
        name: "Regular User",
        organization_id: org.id
      })

    {:ok, regular_user} =
      ViralEngine.UserContext.create_user(%{
        email: "user@example.com",
        name: "Regular User"
      })

    # Assign admin role
    {:ok, admin_role} = RBACContext.get_role_by_name("admin")
    RBACContext.assign_role(admin_user.id, admin_role.id, org.id)

    %{org: org, admin_user: admin_user, regular_user: regular_user, tenant_id: tenant_id}
  end

  describe "PUT /api/users/:id/rate-limits" do
    test "admin can update their own rate limits", %{conn: conn, admin_user: admin_user} do
      conn =
        put(conn, "/api/users/#{admin_user.id}/rate-limits", %{
          rate_limits: %{
            tasks_per_hour: 50,
            concurrent_tasks: 10
          }
        })

      assert response(conn, 200)
      response_data = json_response(conn, 200)

      assert response_data["data"]["user_id"] == admin_user.id
      assert response_data["data"]["tasks_per_hour"] == 50
      assert response_data["data"]["concurrent_tasks"] == 10
    end

    test "admin can update other users' rate limits", %{
      conn: conn,
      admin_user: admin_user,
      regular_user: regular_user,
      org: org
    } do
      # Simulate admin authentication
      conn =
        conn
        |> assign(:current_user_id, admin_user.id)
        |> assign(:current_organization_id, org.id)

      conn =
        put(conn, "/api/users/#{regular_user.id}/rate-limits", %{
          rate_limits: %{
            tasks_per_hour: 25,
            concurrent_tasks: 5
          }
        })

      assert response(conn, 200)
      response_data = json_response(conn, 200)

      assert response_data["data"]["user_id"] == regular_user.id
      assert response_data["data"]["tasks_per_hour"] == 25
      assert response_data["data"]["concurrent_tasks"] == 5
    end

    test "regular user cannot update other users' rate limits", %{
      conn: conn,
      regular_user: regular_user,
      admin_user: admin_user,
      org: org
    } do
      conn =
        conn
        |> assign(:current_user_id, regular_user.id)
        |> assign(:current_organization_id, org.id)

      conn =
        put(conn, "/api/users/#{admin_user.id}/rate-limits", %{
          rate_limits: %{
            tasks_per_hour: 25,
            concurrent_tasks: 5
          }
        })

      assert response(conn, 403)
      response_data = json_response(conn, 403)
      assert response_data["error"] == "Insufficient permissions to manage rate limits"
    end

    test "returns 422 for invalid parameters", %{conn: conn, admin_user: admin_user} do
      conn =
        put(conn, "/api/users/#{admin_user.id}/rate-limits", %{
          rate_limits: %{
            # Invalid
            tasks_per_hour: -1,
            concurrent_tasks: 5
          }
        })

      assert response(conn, 422)
      response_data = json_response(conn, 422)
      assert response_data["errors"] != %{}
    end
  end

  describe "GET /api/users/:id/rate-limits" do
    test "user can view their own rate limits", %{conn: conn, admin_user: admin_user} do
      # First set some custom limits
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: admin_user.id,
          tasks_per_hour: 75,
          concurrent_tasks: 8
        })

      conn = get(conn, "/api/users/#{admin_user.id}/rate-limits")

      assert response(conn, 200)
      response_data = json_response(conn, 200)

      assert response_data["data"]["user_id"] == admin_user.id
      assert response_data["data"]["tasks_per_hour"] == 75
      assert response_data["data"]["concurrent_tasks"] == 8
      assert response_data["data"]["is_default"] == false
    end

    test "returns default limits when no custom limits set", %{
      conn: conn,
      regular_user: regular_user
    } do
      conn = get(conn, "/api/users/#{regular_user.id}/rate-limits")

      assert response(conn, 200)
      response_data = json_response(conn, 200)

      assert response_data["data"]["user_id"] == regular_user.id
      # Default
      assert response_data["data"]["tasks_per_hour"] == 100
      # Default
      assert response_data["data"]["concurrent_tasks"] == 5
      assert response_data["data"]["is_default"] == true
    end

    test "admin can view other users' rate limits", %{
      conn: conn,
      admin_user: admin_user,
      regular_user: regular_user,
      org: org
    } do
      conn =
        conn
        |> assign(:current_user_id, admin_user.id)
        |> assign(:current_organization_id, org.id)

      conn = get(conn, "/api/users/#{regular_user.id}/rate-limits")

      assert response(conn, 200)
    end

    test "regular user cannot view other users' rate limits", %{
      conn: conn,
      regular_user: regular_user,
      admin_user: admin_user,
      org: org
    } do
      conn =
        conn
        |> assign(:current_user_id, regular_user.id)
        |> assign(:current_organization_id, org.id)

      conn = get(conn, "/api/users/#{admin_user.id}/rate-limits")

      assert response(conn, 403)
    end
  end

  describe "DELETE /api/users/:id/rate-limits" do
    test "user can delete their own custom rate limits", %{conn: conn, admin_user: admin_user} do
      # First set custom limits
      {:ok, _} =
        RateLimitContext.upsert_rate_limit(%{
          user_id: admin_user.id,
          tasks_per_hour: 75,
          concurrent_tasks: 8
        })

      conn = delete(conn, "/api/users/#{admin_user.id}/rate-limits")

      assert response(conn, 200)
      response_data = json_response(conn, 200)
      assert response_data["message"] == "Rate limits reset to defaults"
    end

    test "returns 200 when trying to delete non-existent custom limits", %{
      conn: conn,
      regular_user: regular_user
    } do
      conn = delete(conn, "/api/users/#{regular_user.id}/rate-limits")

      assert response(conn, 200)
      response_data = json_response(conn, 200)
      assert response_data["message"] == "Already using default rate limits"
    end

    test "regular user cannot delete other users' rate limits", %{
      conn: conn,
      regular_user: regular_user,
      admin_user: admin_user,
      org: org
    } do
      conn =
        conn
        |> assign(:current_user_id, regular_user.id)
        |> assign(:current_organization_id, org.id)

      conn = delete(conn, "/api/users/#{admin_user.id}/rate-limits")

      assert response(conn, 403)
    end
  end
end
