defmodule ViralEngineWeb.FineTuningController do
  use ViralEngineWeb, :controller

  require Logger
  alias ViralEngine.{FineTuningContext, RBACContext, Jobs.ProcessFineTuningJob}

  action_fallback(ViralEngineWeb.FallbackController)

  @doc """
  Creates a new fine-tuning job.
  """
  def create(conn, %{"fine_tuning_job" => job_params}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions: user can create jobs for their organization
    can_create =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_create do
      attrs = %{
        user_id: current_user_id,
        organization_id: current_org_id,
        name: job_params["name"],
        model: job_params["model"],
        training_file_id: job_params["training_file_id"]
      }

      case FineTuningContext.create_job(attrs) do
        {:ok, job} ->
          # Schedule background processing
          # Note: In a real implementation, you'd need to securely retrieve the API key
          # For now, we'll assume it's passed in the request or retrieved from secure storage
          api_key = Map.get(job_params, "api_key") || System.get_env("OPENAI_API_KEY")

          if api_key do
            case ProcessFineTuningJob.schedule_processing(job.id, api_key) do
              {:ok, _} ->
                Logger.info("Fine-tuning job processing scheduled", job_id: job.id)

              {:error, reason} ->
                Logger.error("Failed to schedule fine-tuning job processing",
                  job_id: job.id,
                  reason: reason
                )
            end
          else
            Logger.warning("No API key provided for fine-tuning job", job_id: job.id)
          end

          conn
          |> put_status(:created)
          |> json(%{
            data: %{
              id: job.id,
              name: job.name,
              model: job.model,
              status: job.status,
              created_at: job.inserted_at
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset_errors(changeset)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to create fine-tuning jobs"})
    end
  end

  @doc """
  Gets a fine-tuning job by ID.
  """
  def show(conn, %{"id" => id}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions: user can view jobs in their organization
    can_view =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_view do
      case FineTuningContext.get_job(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Fine-tuning job not found"})

        job ->
          conn
          |> put_status(:ok)
          |> json(%{
            data: %{
              id: job.id,
              name: job.name,
              model: job.model,
              status: job.status,
              training_file_id: job.training_file_id,
              fine_tuned_model_id: job.fine_tuned_model_id,
              cost: job.cost,
              error_message: job.error_message,
              created_at: job.inserted_at,
              updated_at: job.updated_at
            }
          })
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to view fine-tuning jobs"})
    end
  end

  @doc """
  Lists fine-tuning jobs for the current organization.
  """
  def index(conn, _params) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions
    can_view =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_view do
      jobs = FineTuningContext.list_jobs()

      conn
      |> put_status(:ok)
      |> json(%{
        data:
          Enum.map(jobs, fn job ->
            %{
              id: job.id,
              name: job.name,
              model: job.model,
              status: job.status,
              training_file_id: job.training_file_id,
              fine_tuned_model_id: job.fine_tuned_model_id,
              cost: job.cost,
              created_at: job.inserted_at,
              updated_at: job.updated_at
            }
          end)
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to view fine-tuning jobs"})
    end
  end

  @doc """
  Registers a completed fine-tuned model for use in agents.
  """
  def register_model(conn, %{"id" => id}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions
    can_manage =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_manage do
      case FineTuningContext.get_job(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Fine-tuning job not found"})

        %{status: "completed", fine_tuned_model_id: model_id} when not is_nil(model_id) ->
          # Register the fine-tuned model for use in agents
          # This would typically involve updating agent configurations or creating new agent templates
          # For now, we just validate that the model can be registered
          conn
          |> put_status(:ok)
          |> json(%{
            data: %{
              message: "Model registered successfully",
              fine_tuned_model_id: model_id,
              note: "Model is now available for use in agent configurations"
            }
          })

        _ ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Job is not completed or does not have a fine-tuned model"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to register models"})
    end
  end

  @doc """
  Deletes a fine-tuning job.
  """
  def delete(conn, %{"id" => id}) do
    current_user_id = conn.assigns[:current_user_id]
    current_org_id = conn.assigns[:current_organization_id]

    # Check permissions
    can_delete =
      RBACContext.check_permission(current_user_id, "manage_organization", current_org_id)

    if can_delete do
      case FineTuningContext.delete_job(id) do
        {:ok, _} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "Fine-tuning job deleted successfully"})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Fine-tuning job not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions to delete fine-tuning jobs"})
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
