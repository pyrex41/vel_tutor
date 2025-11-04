defmodule ViralEngine.WorkflowTemplateContext do
  alias ViralEngine.{WorkflowTemplate, WorkflowContext, Repo}
  import Ecto.Query

  def create_template(attrs) do
    changeset =
      WorkflowTemplate.changeset(%WorkflowTemplate{}, attrs)

    Repo.insert(changeset)
  end

  def get_template(id) do
    case Repo.get(WorkflowTemplate, id) do
      nil -> {:error, :not_found}
      template -> {:ok, template}
    end
  end

  def list_templates(filters \\ %{}) do
    query = from(t in WorkflowTemplate)

    query =
      if filters[:created_by] do
        where(query, [t], t.created_by == ^filters.created_by)
      else
        query
      end

    query =
      if filters[:is_public] do
        where(query, [t], t.is_public == true)
      else
        query
      end

    query =
      if filters[:name_contains] do
        where(query, [t], ilike(t.name, ^"%#{filters.name_contains}%"))
      else
        query
      end

    Repo.all(query)
  end

  def list_public_templates do
    list_templates(%{is_public: true})
  end

  def update_template(id, attrs) do
    Repo.transaction(fn ->
      case Repo.get(WorkflowTemplate, id) do
        nil ->
          Repo.rollback(:not_found)

        template ->
          # Create new version
          new_version = template.version + 1
          attrs_with_version = Map.put(attrs, :version, new_version)

          changeset =
            WorkflowTemplate.changeset(template, attrs_with_version)

          case Repo.update(changeset) do
            {:ok, updated_template} -> updated_template
            {:error, changeset} -> Repo.rollback(changeset)
          end
      end
    end)
  end

  def delete_template(id) do
    case Repo.get(WorkflowTemplate, id) do
      nil -> {:error, :not_found}
      template -> Repo.delete(template)
    end
  end

  def create_template_from_workflow(workflow_id, template_attrs) do
    case WorkflowContext.get_workflow_state(workflow_id) do
      {:error, :not_found} ->
        {:error, :workflow_not_found}

      {:ok, _state} ->
        workflow = WorkflowContext.list_workflow_versions(workflow_id) |> List.first()

        template_data = %{
          "name" => workflow.name,
          "state" => workflow.state,
          "routing_rules" => workflow.routing_rules,
          "conditions" => workflow.conditions,
          "approval_gates" => workflow.approval_gates,
          "status" => "active"
        }

        attrs =
          template_attrs
          |> Map.put(:template_data, template_data)
          |> Map.put(:version, 1)

        create_template(attrs)
    end
  end

  def instantiate_workflow(template_id, variables \\ %{}) do
    case get_template(template_id) do
      {:error, :not_found} ->
        {:error, :template_not_found}

      {:ok, template} ->
        # Substitute variables in template data
        substituted_data = substitute_variables(template.template_data, variables)

        # Create workflow name with variables if provided
        workflow_name =
          if variables["workflow_name"] do
            variables["workflow_name"]
          else
            "#{template.name} (from template)"
          end

        # Create the workflow
        WorkflowContext.create_workflow(workflow_name, substituted_data["state"] || %{})
    end
  end

  # Public for testing
  def substitute_variables(data, variables) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      Map.put(acc, key, substitute_variables(value, variables))
    end)
  end

  def substitute_variables(data, variables) when is_list(data) do
    Enum.map(data, &substitute_variables(&1, variables))
  end

  def substitute_variables(data, variables) when is_binary(data) do
    # Replace {{variable_name}} patterns
    Regex.replace(~r/\{\{(\w+)\}\}/, data, fn _, var_name ->
      # Keep placeholder if not found
      Map.get(variables, var_name, "{{#{var_name}}}")
    end)
  end

  def substitute_variables(data, _variables), do: data
end
