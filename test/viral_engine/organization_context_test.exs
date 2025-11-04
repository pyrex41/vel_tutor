defmodule ViralEngine.OrganizationContextTest do
  use ViralEngine.DataCase

  alias ViralEngine.OrganizationContext

  describe "create_organization/1" do
    test "creates a new organization with generated tenant_id" do
      attrs = %{name: "Test Organization", description: "A test org"}

      assert {:ok, organization} = OrganizationContext.create_organization(attrs)
      assert organization.name == "Test Organization"
      assert organization.description == "A test org"
      assert organization.status == "active"
      assert organization.tenant_id != nil
      # UUID length
      assert String.length(organization.tenant_id) == 36
    end

    test "fails with invalid data" do
      # Invalid: empty name
      attrs = %{name: ""}

      assert {:error, changeset} = OrganizationContext.create_organization(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_organization/1" do
    test "returns organization when found" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      assert found_org = OrganizationContext.get_organization(organization.id)
      assert found_org.id == organization.id
    end

    test "returns nil when not found" do
      assert OrganizationContext.get_organization(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_organization_by_tenant_id/1" do
    test "returns organization when found by tenant_id" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      assert found_org = OrganizationContext.get_organization_by_tenant_id(organization.tenant_id)
      assert found_org.id == organization.id
    end

    test "returns nil when tenant_id not found" do
      assert OrganizationContext.get_organization_by_tenant_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_organizations/0" do
    test "returns all organizations ordered by inserted_at desc" do
      {:ok, org1} = OrganizationContext.create_organization(%{name: "Org 1"})
      {:ok, org2} = OrganizationContext.create_organization(%{name: "Org 2"})

      organizations = OrganizationContext.list_organizations()

      assert length(organizations) >= 2
      # Should be ordered by inserted_at desc (most recent first)
      assert hd(organizations).name in ["Org 1", "Org 2"]
    end
  end

  describe "update_organization/2" do
    test "updates organization with valid data" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      update_attrs = %{description: "Updated description", max_users: 50}

      assert {:ok, updated_org} =
               OrganizationContext.update_organization(organization, update_attrs)

      assert updated_org.description == "Updated description"
      assert updated_org.max_users == 50
    end

    test "fails with invalid data" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      # Invalid: negative number
      update_attrs = %{max_users: -1}

      assert {:error, changeset} =
               OrganizationContext.update_organization(organization, update_attrs)

      assert %{max_users: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "delete_organization/1" do
    test "soft deletes organization by setting status to deleted" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      assert {:ok, deleted_org} = OrganizationContext.delete_organization(organization)
      assert deleted_org.status == "deleted"
    end
  end

  describe "organization_active?/1" do
    test "returns true for active organization" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})
      assert OrganizationContext.organization_active?(organization) == true
    end

    test "returns false for suspended organization" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      {:ok, suspended_org} =
        OrganizationContext.update_organization(organization, %{status: "suspended"})

      assert OrganizationContext.organization_active?(suspended_org) == false
    end

    test "returns false for nil" do
      assert OrganizationContext.organization_active?(nil) == false
    end
  end

  describe "tenant context management" do
    test "set_current_tenant_id and current_tenant_id work correctly" do
      tenant_id = Ecto.UUID.generate()

      OrganizationContext.set_current_tenant_id(tenant_id)
      assert OrganizationContext.current_tenant_id() == tenant_id

      OrganizationContext.clear_current_tenant_id()
      assert OrganizationContext.current_tenant_id() == nil
    end

    test "ensure_tenant_context succeeds for valid organization" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})

      assert {:ok, found_org} = OrganizationContext.ensure_tenant_context(organization.tenant_id)
      assert found_org.id == organization.id
    end

    test "ensure_tenant_context fails for non-existent tenant" do
      assert {:error, :organization_not_found} =
               OrganizationContext.ensure_tenant_context(Ecto.UUID.generate())
    end

    test "ensure_tenant_context fails for inactive organization" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})
      {:ok, _} = OrganizationContext.update_organization(organization, %{status: "suspended"})

      assert {:error, :organization_inactive} =
               OrganizationContext.ensure_tenant_context(organization.tenant_id)
    end
  end

  describe "current_organization/0" do
    test "returns current organization when tenant context is set" do
      {:ok, organization} = OrganizationContext.create_organization(%{name: "Test Org"})
      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      assert current_org = OrganizationContext.current_organization()
      assert current_org.id == organization.id

      OrganizationContext.clear_current_tenant_id()
    end

    test "returns nil when no tenant context" do
      OrganizationContext.clear_current_tenant_id()
      assert OrganizationContext.current_organization() == nil
    end
  end

  describe "validate_tenant_access/1" do
    test "succeeds when resource tenant matches current tenant" do
      tenant_id = Ecto.UUID.generate()
      OrganizationContext.set_current_tenant_id(tenant_id)

      assert OrganizationContext.validate_tenant_access(tenant_id) == :ok

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when resource tenant doesn't match current tenant" do
      OrganizationContext.set_current_tenant_id(Ecto.UUID.generate())

      assert OrganizationContext.validate_tenant_access(Ecto.UUID.generate()) ==
               {:error, :access_denied}

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when no current tenant context" do
      OrganizationContext.clear_current_tenant_id()

      assert OrganizationContext.validate_tenant_access(Ecto.UUID.generate()) ==
               {:error, :access_denied}
    end
  end

  describe "check_user_limits/1" do
    test "succeeds when under user limit" do
      {:ok, organization} =
        OrganizationContext.create_organization(%{name: "Test Org", max_users: 10})

      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      assert OrganizationContext.check_user_limits(5) == :ok

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when over user limit" do
      {:ok, organization} =
        OrganizationContext.create_organization(%{name: "Test Org", max_users: 10})

      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      assert OrganizationContext.check_user_limits(15) == {:error, :user_limit_exceeded}

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when no organization context" do
      OrganizationContext.clear_current_tenant_id()

      assert OrganizationContext.check_user_limits(5) == {:error, :no_organization}
    end
  end

  describe "check_task_limits/1" do
    test "succeeds when under task limit" do
      {:ok, organization} =
        OrganizationContext.create_organization(%{name: "Test Org", max_tasks_per_month: 1000})

      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      assert OrganizationContext.check_task_limits(500) == :ok

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when over task limit" do
      {:ok, organization} =
        OrganizationContext.create_organization(%{name: "Test Org", max_tasks_per_month: 1000})

      OrganizationContext.set_current_tenant_id(organization.tenant_id)

      assert OrganizationContext.check_task_limits(1500) == {:error, :task_limit_exceeded}

      OrganizationContext.clear_current_tenant_id()
    end

    test "fails when no organization context" do
      OrganizationContext.clear_current_tenant_id()

      assert OrganizationContext.check_task_limits(500) == {:error, :no_organization}
    end
  end
end
