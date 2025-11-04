defmodule ViralEngineWeb.FineTuningControllerTest do
  use ViralEngineWeb.ConnCase, async: true

  alias ViralEngine.{FineTuningContext, OrganizationContext}

  setup %{conn: conn} do
    # Set up tenant context for tests
    tenant_id = Ecto.UUID.generate()
    OrganizationContext.set_current_tenant_id(tenant_id)

    # Create a user and organization for testing
    {:ok, organization} =
      ViralEngine.OrganizationContext.create_organization(%{
        name: "Test Org",
        tenant_id: tenant_id
      })

    {:ok, user} =
      ViralEngine.Repo.insert(%ViralEngine.User{
        email: "test@example.com",
        name: "Test User",
        organization_id: organization.id
      })

    # Create rate limit record for the user
    {:ok, _rate_limit} =
      ViralEngine.Repo.insert(%ViralEngine.RateLimit{
        tenant_id: tenant_id,
        user_id: user.id,
        tasks_per_hour: 1000,
        concurrent_tasks: 10,
        current_hourly_count: 0,
        current_concurrent_count: 0
      })

    # Set up RBAC permissions for fine-tuning
    {:ok, permission} =
      ViralEngine.RBACContext.create_permission(%{
        name: "manage_organization",
        description: "Can manage organization resources"
      })

    {:ok, role} =
      ViralEngine.RBACContext.create_role(%{
        name: "admin",
        description: "Administrator role",
        organization_id: organization.id
      })

    # Add permission to role
    ViralEngine.Repo.insert_all("roles_permissions", [
      %{
        role_id: role.id,
        permission_id: permission.id,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    # Assign role to user
    ViralEngine.RBACContext.assign_role(user.id, role.id, organization.id)

    # Set up authenticated connection
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("x-tenant-id", tenant_id)
      |> assign(:current_user_id, user.id)
      |> assign(:current_organization_id, organization.id)

    %{conn: conn, user: user, organization: organization, tenant_id: tenant_id}
  end

  describe "POST /api/fine-tuning-jobs" do
    test "creates a fine-tuning job with valid data", %{
      conn: conn,
      user: user,
      organization: organization
    } do
      job_params = %{
        name: "Test Fine-tuning Job",
        model: "gpt-3.5-turbo",
        training_file_id: "file-123",
        api_key: "sk-test123"
      }

      conn = post(conn, "/api/fine-tuning-jobs", %{"fine_tuning_job" => job_params})

      assert %{"data" => job_data} = json_response(conn, 201)
      assert job_data["id"]
      assert job_data["name"] == "Test Fine-tuning Job"
      assert job_data["model"] == "gpt-3.5-turbo"
      assert job_data["status"] == "pending"
      assert job_data["created_at"]
    end

    test "returns error with invalid data", %{conn: conn} do
      job_params = %{
        # Missing required name
        model: "gpt-3.5-turbo"
      }

      conn = post(conn, "/api/fine-tuning-jobs", %{"fine_tuning_job" => job_params})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["name"] == ["can't be blank"]
    end

    test "validates model type", %{conn: conn} do
      job_params = %{
        name: "Test Job",
        model: "invalid-model",
        api_key: "sk-test123"
      }

      conn = post(conn, "/api/fine-tuning-jobs", %{"fine_tuning_job" => job_params})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["model"] == ["is invalid"]
    end
  end

  describe "GET /api/fine-tuning-jobs" do
    setup %{user: user, organization: organization} do
      # Create test jobs
      {:ok, job1} =
        FineTuningContext.create_job(%{
          user_id: user.id,
          organization_id: organization.id,
          name: "Job 1",
          model: "gpt-3.5-turbo"
        })

      {:ok, job2} =
        FineTuningContext.create_job(%{
          user_id: user.id,
          organization_id: organization.id,
          name: "Job 2",
          model: "gpt-4"
        })

      %{jobs: [job1, job2]}
    end

    test "lists fine-tuning jobs for current organization", %{conn: conn, jobs: jobs} do
      conn = get(conn, "/api/fine-tuning-jobs")

      assert %{"data" => jobs_data} = json_response(conn, 200)
      assert length(jobs_data) == 2

      job_names = Enum.map(jobs_data, & &1["name"]) |> Enum.sort()
      expected_names = Enum.map(jobs, & &1.name) |> Enum.sort()
      assert job_names == expected_names
    end

    test "includes all job fields in response", %{conn: conn, jobs: [job | _]} do
      conn = get(conn, "/api/fine-tuning-jobs")

      assert %{"data" => [job_data | _]} = json_response(conn, 200)
      assert job_data["id"] == job.id
      assert job_data["name"] == job.name
      assert job_data["model"] == job.model
      assert job_data["status"] == job.status
      assert job_data["training_file_id"] == job.training_file_id
      assert job_data["fine_tuned_model_id"] == job.fine_tuned_model_id
      assert job_data["cost"] == job.cost
      assert job_data["created_at"]
      assert job_data["updated_at"]
    end
  end

  describe "GET /api/fine-tuning-jobs/:id" do
    setup %{user: user, organization: organization} do
      {:ok, job} =
        FineTuningContext.create_job(%{
          user_id: user.id,
          organization_id: organization.id,
          name: "Test Job",
          model: "gpt-3.5-turbo",
          training_file_id: "file-123"
        })

      # Update job with some data
      FineTuningContext.update_job(job, %{
        status: "completed",
        fine_tuned_model_id: "ft:gpt-3.5-turbo:org:model123",
        cost: Decimal.new("5.50"),
        error_message: nil
      })

      %{job: job}
    end

    test "shows fine-tuning job details", %{conn: conn, job: job} do
      conn = get(conn, "/api/fine-tuning-jobs/#{job.id}")

      assert %{"data" => job_data} = json_response(conn, 200)
      assert job_data["id"] == job.id
      assert job_data["name"] == "Test Job"
      assert job_data["model"] == "gpt-3.5-turbo"
      assert job_data["status"] == "completed"
      assert job_data["training_file_id"] == "file-123"
      assert job_data["fine_tuned_model_id"] == "ft:gpt-3.5-turbo:org:model123"
      assert job_data["cost"] == "5.50"
      assert job_data["error_message"] == nil
    end

    test "returns 404 for non-existent job", %{conn: conn} do
      conn = get(conn, "/api/fine-tuning-jobs/#{Ecto.UUID.generate()}")

      assert %{"error" => "Fine-tuning job not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/fine-tuning-jobs/:id/register" do
    setup %{user: user, organization: organization} do
      {:ok, job} =
        FineTuningContext.create_job(%{
          user_id: user.id,
          organization_id: organization.id,
          name: "Test Job",
          model: "gpt-3.5-turbo"
        })

      %{job: job}
    end

    test "registers completed job successfully", %{conn: conn, job: job} do
      # Mark job as completed with fine-tuned model
      FineTuningContext.update_job(job, %{
        status: "completed",
        fine_tuned_model_id: "ft:gpt-3.5-turbo:org:model123"
      })

      conn = post(conn, "/api/fine-tuning-jobs/#{job.id}/register")

      assert %{"data" => response_data} = json_response(conn, 200)
      assert response_data["message"] == "Model registered successfully"
      assert response_data["fine_tuned_model_id"] == "ft:gpt-3.5-turbo:org:model123"
      assert response_data["note"] == "Model is now available for use in agent configurations"
    end

    test "returns error for pending job", %{conn: conn, job: job} do
      conn = post(conn, "/api/fine-tuning-jobs/#{job.id}/register")

      assert %{"error" => "Job is not completed or does not have a fine-tuned model"} =
               json_response(conn, 422)
    end

    test "returns error for failed job", %{conn: conn, job: job} do
      FineTuningContext.update_job(job, %{status: "failed"})

      conn = post(conn, "/api/fine-tuning-jobs/#{job.id}/register")

      assert %{"error" => "Job is not completed or does not have a fine-tuned model"} =
               json_response(conn, 422)
    end

    test "returns 404 for non-existent job", %{conn: conn} do
      conn = post(conn, "/api/fine-tuning-jobs/#{Ecto.UUID.generate()}/register")

      assert %{"error" => "Fine-tuning job not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/fine-tuning-jobs/:id" do
    setup %{user: user, organization: organization} do
      {:ok, job} =
        FineTuningContext.create_job(%{
          user_id: user.id,
          organization_id: organization.id,
          name: "Test Job",
          model: "gpt-3.5-turbo"
        })

      %{job: job}
    end

    test "deletes fine-tuning job successfully", %{conn: conn, job: job} do
      conn = delete(conn, "/api/fine-tuning-jobs/#{job.id}")

      assert %{"message" => "Fine-tuning job deleted successfully"} = json_response(conn, 200)

      # Verify job is gone
      conn = get(conn, "/api/fine-tuning-jobs/#{job.id}")
      assert json_response(conn, 404)
    end

    test "returns 404 for non-existent job", %{conn: conn} do
      conn = delete(conn, "/api/fine-tuning-jobs/#{Ecto.UUID.generate()}")

      assert %{"error" => "Fine-tuning job not found"} = json_response(conn, 404)
    end
  end

  describe "authorization" do
    test "requires organization membership for all actions", %{conn: conn} do
      # Remove organization assignment
      conn = assign(conn, :current_organization_id, nil)

      conn = post(conn, "/api/fine-tuning-jobs", %{"fine_tuning_job" => %{name: "Test"}})
      assert json_response(conn, 403)

      conn = get(conn, "/api/fine-tuning-jobs")
      assert json_response(conn, 403)
    end
  end
end
