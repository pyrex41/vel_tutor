defmodule ViralEngineWeb.WorkflowTemplateController do
  use ViralEngineWeb, :controller

  # Deprecated :namespace option - use plug :put_layout instead if needed
  # Set formats for proper rendering
  plug :accepts, ["html", "json"]
  alias ViralEngine.WorkflowTemplateContext

  def create(conn, %{"workflow_id" => workflow_id} = params) do
    template_attrs = %{
      name: params["name"],
      description: params["description"],
      is_public: params["is_public"] || false,
      created_by: params["created_by"] || "anonymous"
    }

    case WorkflowTemplateContext.create_template_from_workflow(
           String.to_integer(workflow_id),
           template_attrs
         ) do
      {:ok, template} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          is_public: template.is_public,
          created_by: template.created_by
        })

      {:error, :workflow_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workflow not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def create(conn, params) do
    template_attrs = %{
      name: params["name"],
      description: params["description"],
      is_public: params["is_public"] || false,
      template_data: params["template_data"],
      created_by: params["created_by"] || "anonymous"
    }

    case WorkflowTemplateContext.create_template(template_attrs) do
      {:ok, template} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          is_public: template.is_public,
          created_by: template.created_by
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def index(conn, params) do
    filters = %{}

    filters =
      if params["created_by"],
        do: Map.put(filters, :created_by, params["created_by"]),
        else: filters

    filters =
      if params["name_contains"],
        do: Map.put(filters, :name_contains, params["name_contains"]),
        else: filters

    templates = WorkflowTemplateContext.list_templates(filters)

    templates_data =
      Enum.map(templates, fn template ->
        %{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          is_public: template.is_public,
          created_by: template.created_by,
          inserted_at: template.inserted_at
        }
      end)

    conn
    |> json(%{templates: templates_data})
  end

  def public(conn, _params) do
    templates = WorkflowTemplateContext.list_public_templates()

    templates_data =
      Enum.map(templates, fn template ->
        %{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          created_by: template.created_by,
          inserted_at: template.inserted_at
        }
      end)

    conn
    |> json(%{templates: templates_data})
  end

  def show(conn, %{"id" => id}) do
    case WorkflowTemplateContext.get_template(String.to_integer(id)) do
      {:ok, template} ->
        conn
        |> json(%{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          is_public: template.is_public,
          template_data: template.template_data,
          created_by: template.created_by,
          inserted_at: template.inserted_at,
          updated_at: template.updated_at
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Template not found"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    update_attrs = %{}

    update_attrs =
      if params["name"], do: Map.put(update_attrs, :name, params["name"]), else: update_attrs

    update_attrs =
      if params["description"],
        do: Map.put(update_attrs, :description, params["description"]),
        else: update_attrs

    update_attrs =
      if params["is_public"] != nil,
        do: Map.put(update_attrs, :is_public, params["is_public"]),
        else: update_attrs

    update_attrs =
      if params["template_data"],
        do: Map.put(update_attrs, :template_data, params["template_data"]),
        else: update_attrs

    case WorkflowTemplateContext.update_template(String.to_integer(id), update_attrs) do
      {:ok, template} ->
        conn
        |> json(%{
          id: template.id,
          name: template.name,
          description: template.description,
          version: template.version,
          is_public: template.is_public,
          created_by: template.created_by
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Template not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case WorkflowTemplateContext.delete_template(String.to_integer(id)) do
      {:ok, _template} ->
        conn
        |> put_status(:no_content)
        |> json(%{})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Template not found"})
    end
  end

  def instantiate(conn, %{"id" => id} = params) do
    variables = params["variables"] || %{}

    case WorkflowTemplateContext.instantiate_workflow(String.to_integer(id), variables) do
      {:ok, workflow} ->
        conn
        |> put_status(:created)
        |> json(%{
          workflow_id: workflow.id,
          name: workflow.name,
          state: workflow.state,
          version: workflow.version
        })

      {:error, :template_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Template not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
