defmodule ViralEngine.FineTuningContextTest do
  use ViralEngine.DataCase

  alias ViralEngine.{FineTuningContext, FineTuningJob, OrganizationContext, Repo, User}

  setup do
    # Create a test user
    {:ok, user} = Repo.insert(%User{email: "test@example.com", name: "Test User"})
    %{user: user}
  end

  setup %{user: user} do
    # Create a test organization for the user
    {:ok, organization} =
      Repo.insert(%ViralEngine.Organization{
        name: "Test Organization",
        tenant_id: Ecto.UUID.generate()
      })

    # Update user with organization_id
    {:ok, user} = Repo.update(Ecto.Changeset.change(user, organization_id: organization.id))

    %{user: user, organization: organization}
  end

  describe "create_job/1" do
    test "creates a fine-tuning job with valid attributes", %{
      user: user,
      organization: organization
    } do
      # Set up tenant context
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Fine-tuning Job",
        model: "gpt-3.5-turbo",
        training_file_id: "file-123"
      }

      assert {:ok, %FineTuningJob{} = job} = FineTuningContext.create_job(attrs)
      assert job.tenant_id == organization.tenant_id
      assert job.name == "Test Fine-tuning Job"
      assert job.model == "gpt-3.5-turbo"
      assert job.status == "pending"
    end

    test "returns error when no tenant context is set", %{user: user, organization: organization} do
      OrganizationContext.clear_current_tenant_id()

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Job",
        model: "gpt-3.5-turbo"
      }

      assert {:error, :no_tenant_context} = FineTuningContext.create_job(attrs)
    end

    test "validates required fields", %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      # Missing name
      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        model: "gpt-3.5-turbo"
      }

      assert {:error, %Ecto.Changeset{}} = FineTuningContext.create_job(attrs)
    end
  end

  describe "get_job/1" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Job",
        model: "gpt-3.5-turbo"
      }

      {:ok, job} = FineTuningContext.create_job(attrs)
      %{job: job, tenant_id: organization.tenant_id}
    end

    test "returns job when it exists and tenant matches", %{job: job} do
      assert returned_job = FineTuningContext.get_job(job.id)
      assert returned_job.id == job.id
    end

    test "returns nil when job doesn't exist" do
      assert FineTuningContext.get_job(Ecto.UUID.generate()) == nil
    end

    test "returns nil when no tenant context" do
      OrganizationContext.clear_current_tenant_id()
      assert FineTuningContext.get_job(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_jobs/0" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      # Create jobs for current tenant
      attrs1 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Job 1",
        model: "gpt-3.5-turbo"
      }

      attrs2 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Job 2",
        model: "gpt-4"
      }

      {:ok, job1} = FineTuningContext.create_job(attrs1)
      {:ok, job2} = FineTuningContext.create_job(attrs2)

      # Create job for different tenant
      other_tenant_id = Ecto.UUID.generate()
      OrganizationContext.set_current_tenant_id(other_tenant_id)

      # Create another organization and user for the other tenant
      {:ok, other_org} =
        Repo.insert(%ViralEngine.Organization{
          name: "Other Organization",
          tenant_id: other_tenant_id
        })

      {:ok, other_user} =
        Repo.insert(%ViralEngine.User{
          email: "other@example.com",
          name: "Other User",
          organization_id: other_org.id
        })

      attrs3 = %{
        user_id: other_user.id,
        organization_id: other_org.id,
        name: "Other Tenant Job",
        model: "gpt-3.5-turbo"
      }

      {:ok, _other_job} = FineTuningContext.create_job(attrs3)

      # Switch back
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      %{jobs: [job1, job2], tenant_id: organization.tenant_id}
    end

    test "returns jobs for current tenant only", %{jobs: jobs} do
      returned_jobs = FineTuningContext.list_jobs()
      assert length(returned_jobs) == 2

      job_ids = Enum.map(returned_jobs, & &1.id)
      assert job_ids -- Enum.map(jobs, & &1.id) == []
    end

    test "returns empty list when no tenant context" do
      OrganizationContext.clear_current_tenant_id()
      assert FineTuningContext.list_jobs() == []
    end
  end

  describe "update_job/2" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Job",
        model: "gpt-3.5-turbo"
      }

      {:ok, job} = FineTuningContext.create_job(attrs)
      %{job: job}
    end

    test "updates job with valid attributes", %{job: job} do
      update_attrs = %{
        status: "running",
        fine_tuned_model_id: "ft:gpt-3.5-turbo:org:model123",
        cost: Decimal.new("5.50")
      }

      assert {:ok, updated_job} = FineTuningContext.update_job(job, update_attrs)
      assert updated_job.status == "running"
      assert updated_job.fine_tuned_model_id == "ft:gpt-3.5-turbo:org:model123"
      assert updated_job.cost == Decimal.new("5.50")
    end

    test "validates status values", %{job: job} do
      update_attrs = %{status: "invalid_status"}
      assert {:error, %Ecto.Changeset{}} = FineTuningContext.update_job(job, update_attrs)
    end
  end

  describe "update_job_status/3" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Job",
        model: "gpt-3.5-turbo"
      }

      {:ok, job} = FineTuningContext.create_job(attrs)
      %{job: job}
    end

    test "updates job status successfully", %{job: job} do
      additional_attrs = %{fine_tuned_model_id: "ft:model123"}

      assert {:ok, updated_job} =
               FineTuningContext.update_job_status(job.id, "completed", additional_attrs)

      assert updated_job.status == "completed"
      assert updated_job.fine_tuned_model_id == "ft:model123"
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} =
               FineTuningContext.update_job_status(Ecto.UUID.generate(), "running")
    end
  end

  describe "delete_job/1" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      attrs = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Test Job",
        model: "gpt-3.5-turbo"
      }

      {:ok, job} = FineTuningContext.create_job(attrs)
      %{job: job}
    end

    test "deletes existing job", %{job: job} do
      assert {:ok, _deleted_job} = FineTuningContext.delete_job(job.id)
      assert FineTuningContext.get_job(job.id) == nil
    end

    test "returns error for non-existent job" do
      assert {:error, :not_found} = FineTuningContext.delete_job(Ecto.UUID.generate())
    end
  end

  describe "get_jobs_by_status/1" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      # Create jobs with different statuses
      attrs1 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Pending Job",
        model: "gpt-3.5-turbo"
      }

      attrs2 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Running Job",
        model: "gpt-4"
      }

      {:ok, job1} = FineTuningContext.create_job(attrs1)
      {:ok, job2} = FineTuningContext.create_job(attrs2)

      # Update job2 status
      FineTuningContext.update_job_status(job2.id, "running")

      %{pending_job: job1, running_job: job2}
    end

    test "returns jobs with specified status", %{pending_job: pending_job} do
      pending_jobs = FineTuningContext.get_jobs_by_status("pending")
      assert length(pending_jobs) == 1
      assert hd(pending_jobs).id == pending_job.id
    end

    test "returns empty list when no tenant context" do
      OrganizationContext.clear_current_tenant_id()
      assert FineTuningContext.get_jobs_by_status("pending") == []
    end
  end

  describe "total_cost/0" do
    setup %{user: user, organization: organization} do
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      # Create jobs with costs
      attrs1 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Job 1",
        model: "gpt-3.5-turbo"
      }

      attrs2 = %{
        user_id: user.id,
        organization_id: organization.id,
        name: "Job 2",
        model: "gpt-4"
      }

      {:ok, job1} = FineTuningContext.create_job(attrs1)
      {:ok, job2} = FineTuningContext.create_job(attrs2)

      # Set costs
      FineTuningContext.update_job(job1, %{cost: Decimal.new("10.50")})
      FineTuningContext.update_job(job2, %{cost: Decimal.new("25.75")})

      %{tenant_id: organization.tenant_id}
    end

    test "calculates total cost for current tenant" do
      assert FineTuningContext.total_cost() == Decimal.new("36.25")
    end

    test "returns zero when no tenant context" do
      OrganizationContext.clear_current_tenant_id()
      assert FineTuningContext.total_cost() == Decimal.new("0")
    end

    test "returns zero when no jobs have costs" do
      # Create a new tenant with no cost data
      new_tenant_id = Ecto.UUID.generate()
      OrganizationContext.set_current_tenant_id(new_tenant_id)

      # No jobs exist in this new tenant, so total cost should be zero
      assert FineTuningContext.total_cost() == Decimal.new("0")
    end
  end
end
