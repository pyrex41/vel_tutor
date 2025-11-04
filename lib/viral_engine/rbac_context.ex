defmodule ViralEngine.RBACContext do
  @moduledoc """
  Context for managing Role-Based Access Control (RBAC) with multi-tenant support.
  """

  import Ecto.Query
  require Logger
  alias ViralEngine.{Repo, Permission, Role, UserRole, OrganizationContext, AuditLogContext}

  @doc """
  Creates a new permission.
  """
  def create_permission(attrs) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a permission by ID.
  """
  def get_permission(id) do
    Repo.get(Permission, id)
  end

  @doc """
  Gets a permission by name.
  """
  def get_permission_by_name(name) do
    Repo.get_by(Permission, name: name)
  end

  @doc """
  Lists all permissions.
  """
  def list_permissions do
    Repo.all(from(p in Permission, order_by: [asc: p.name]))
  end

  @doc """
  Creates a new role.
  """
  def create_role(attrs) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a role by ID.
  """
  def get_role(id) do
    Repo.get(Role, id)
  end

  @doc """
  Gets a role by name.
  """
  def get_role_by_name(name) do
    Repo.get_by(Role, name: name)
  end

  @doc """
  Lists all roles.
  """
  def list_roles do
    Repo.all(from(r in Role, order_by: [asc: r.name]))
  end

  @doc """
  Assigns a role to a user in an organization.
  """
  def assign_role(user_id, role_id, organization_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      # Validate that the organization belongs to current tenant
      case OrganizationContext.get_organization(organization_id) do
        nil ->
          {:error, :organization_not_found}

        org when org.tenant_id == tenant_id ->
          # Check if assignment already exists
          case Repo.get_by(UserRole,
                 user_id: user_id,
                 role_id: role_id,
                 organization_id: organization_id
               ) do
            nil ->
              # Create new assignment
              changeset =
                UserRole.changeset(%UserRole{}, %{
                  user_id: user_id,
                  role_id: role_id,
                  organization_id: organization_id
                })

              case Repo.insert(changeset) do
                {:ok, user_role} ->
                  # Log audit event
                  AuditLogContext.log_user_action(
                    user_id,
                    "role_assigned",
                    %{role_id: role_id, organization_id: organization_id},
                    nil
                  )

                  {:ok, user_role}

                {:error, changeset} ->
                  {:error, changeset}
              end

            _existing ->
              {:error, :role_already_assigned}
          end

        _org ->
          {:error, :access_denied}
      end
    else
      {:error, :no_tenant_context}
    end
  end

  @doc """
  Revokes a role from a user in an organization.
  """
  def revoke_role(user_id, role_id, organization_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      # Validate that the organization belongs to current tenant
      case OrganizationContext.get_organization(organization_id) do
        nil ->
          {:error, :organization_not_found}

        org when org.tenant_id == tenant_id ->
          case Repo.get_by(UserRole,
                 user_id: user_id,
                 role_id: role_id,
                 organization_id: organization_id
               ) do
            nil ->
              {:error, :role_not_assigned}

            user_role ->
              case Repo.delete(user_role) do
                {:ok, _} ->
                  # Log audit event
                  AuditLogContext.log_user_action(
                    user_id,
                    "role_revoked",
                    %{role_id: role_id, organization_id: organization_id},
                    nil
                  )

                  :ok

                {:error, changeset} ->
                  {:error, changeset}
              end
          end

        _org ->
          {:error, :access_denied}
      end
    else
      {:error, :no_tenant_context}
    end
  end

  @doc """
  Checks if a user has a specific permission in an organization.
  """
  def check_permission(user_id, permission_name, organization_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      # Validate that the organization belongs to current tenant
      case OrganizationContext.get_organization(organization_id) do
        nil ->
          false

        org when org.tenant_id == tenant_id ->
          # Query to check if user has the permission through their roles
          query =
            from(ur in UserRole,
              join: r in Role,
              on: ur.role_id == r.id,
              join: rp in "roles_permissions",
              on: rp.role_id == r.id,
              join: p in Permission,
              on: rp.permission_id == p.id,
              where:
                ur.user_id == ^user_id and
                  ur.organization_id == ^organization_id and
                  p.name == ^permission_name,
              select: count(p.id)
            )

          case Repo.one(query) do
            count when count > 0 -> true
            _ -> false
          end

        _org ->
          false
      end
    else
      false
    end
  end

  @doc """
  Gets all roles for a user in an organization.
  """
  def get_user_roles(user_id, organization_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      case OrganizationContext.get_organization(organization_id) do
        nil ->
          []

        org when org.tenant_id == tenant_id ->
          query =
            from(ur in UserRole,
              join: r in Role,
              on: ur.role_id == r.id,
              where: ur.user_id == ^user_id and ur.organization_id == ^organization_id,
              select: r
            )

          Repo.all(query)

        _org ->
          []
      end
    else
      []
    end
  end

  @doc """
  Gets all permissions for a user in an organization.
  """
  def get_user_permissions(user_id, organization_id) do
    tenant_id = OrganizationContext.current_tenant_id()

    if tenant_id do
      case OrganizationContext.get_organization(organization_id) do
        nil ->
          []

        org when org.tenant_id == tenant_id ->
          query =
            from(ur in UserRole,
              join: r in Role,
              on: ur.role_id == r.id,
              join: rp in "roles_permissions",
              on: rp.role_id == r.id,
              join: p in Permission,
              on: rp.permission_id == p.id,
              where: ur.user_id == ^user_id and ur.organization_id == ^organization_id,
              select: p,
              distinct: true
            )

          Repo.all(query)

        _org ->
          []
      end
    else
      []
    end
  end

  @doc """
  Adds a permission to a role.
  """
  def add_permission_to_role(role_id, permission_id) do
    # Check if the association already exists
    query =
      from(rp in "roles_permissions",
        where: rp.role_id == ^role_id and rp.permission_id == ^permission_id,
        select: count(rp.role_id)
      )

    case Repo.one(query) do
      0 ->
        # Insert the association
        {1, _} =
          Repo.insert_all("roles_permissions", [
            %{
              role_id: role_id,
              permission_id: permission_id,
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
            }
          ])

        Logger.info("Added permission #{permission_id} to role #{role_id}")
        {:ok, :permission_added}

      _ ->
        {:error, :permission_already_assigned}
    end
  end

  @doc """
  Removes a permission from a role.
  """
  def remove_permission_from_role(role_id, permission_id) do
    # Delete the association
    {deleted_count, _} =
      Repo.delete_all(
        from(rp in "roles_permissions",
          where: rp.role_id == ^role_id and rp.permission_id == ^permission_id
        )
      )

    case deleted_count do
      0 ->
        {:error, :permission_not_assigned}

      _ ->
        Logger.info("Removed permission #{permission_id} from role #{role_id}")
        {:ok, :permission_removed}
    end
  end

  @doc """
  Seeds default roles and permissions.
  """
  def seed_default_roles do
    # Define default permissions
    permissions = [
      %{name: "create_agent", description: "Can create AI agents"},
      %{name: "manage_users", description: "Can manage users in organization"},
      %{name: "execute_task", description: "Can execute tasks"},
      %{name: "view_analytics", description: "Can view analytics and reports"},
      %{name: "manage_organization", description: "Can manage organization settings"},
      %{name: "manage_billing", description: "Can manage billing and subscriptions"}
    ]

    # Create permissions
    Enum.each(permissions, fn perm_attrs ->
      case get_permission_by_name(perm_attrs.name) do
        nil ->
          case create_permission(perm_attrs) do
            {:ok, _} -> Logger.info("Created permission: #{perm_attrs.name}")
            {:error, _} -> Logger.error("Failed to create permission: #{perm_attrs.name}")
          end

        _ ->
          Logger.info("Permission already exists: #{perm_attrs.name}")
      end
    end)

    # Define default roles
    roles = [
      %{
        name: "org_admin",
        description: "Organization administrator with full access",
        permissions: [
          "create_agent",
          "manage_users",
          "execute_task",
          "view_analytics",
          "manage_organization",
          "manage_billing"
        ]
      },
      %{
        name: "agent_manager",
        description: "Can manage agents and execute tasks",
        permissions: ["create_agent", "execute_task", "view_analytics"]
      },
      %{
        name: "task_executor",
        description: "Can execute tasks and view basic analytics",
        permissions: ["execute_task", "view_analytics"]
      },
      %{
        name: "viewer",
        description: "Read-only access to analytics",
        permissions: ["view_analytics"]
      }
    ]

    # Create roles and associate permissions
    Enum.each(roles, fn role_attrs ->
      case get_role_by_name(role_attrs.name) do
        nil ->
          # Create role without permissions first
          role_attrs_without_perms = Map.delete(role_attrs, :permissions)

          case create_role(role_attrs_without_perms) do
            {:ok, role} ->
              Logger.info("Created role: #{role_attrs.name}")

              # Associate permissions with the role
              Enum.each(role_attrs.permissions, fn permission_name ->
                case get_permission_by_name(permission_name) do
                  nil ->
                    Logger.error(
                      "Permission #{permission_name} not found for role #{role_attrs.name}"
                    )

                  permission ->
                    case add_permission_to_role(role.id, permission.id) do
                      {:ok, _} ->
                        Logger.info(
                          "Associated permission #{permission_name} with role #{role_attrs.name}"
                        )

                      {:error, reason} ->
                        Logger.error(
                          "Failed to associate permission #{permission_name} with role #{role_attrs.name}: #{inspect(reason)}"
                        )
                    end
                end
              end)

            {:error, _} ->
              Logger.error("Failed to create role: #{role_attrs.name}")
          end

        role ->
          Logger.info("Role already exists: #{role_attrs.name}")
          # Ensure permissions are associated (in case they were added later)
          Enum.each(role_attrs.permissions, fn permission_name ->
            case get_permission_by_name(permission_name) do
              nil ->
                Logger.error(
                  "Permission #{permission_name} not found for role #{role_attrs.name}"
                )

              permission ->
                case add_permission_to_role(role.id, permission.id) do
                  {:ok, _} ->
                    Logger.info(
                      "Associated permission #{permission_name} with existing role #{role_attrs.name}"
                    )

                  {:error, :permission_already_assigned} ->
                    # Already associated, that's fine
                    nil

                  {:error, reason} ->
                    Logger.error(
                      "Failed to associate permission #{permission_name} with role #{role_attrs.name}: #{inspect(reason)}"
                    )
                end
            end
          end)
      end
    end)
  end
end
