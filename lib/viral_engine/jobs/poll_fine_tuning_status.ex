defmodule ViralEngine.Jobs.PollFineTuningStatus do
  @moduledoc """
  Background job to poll OpenAI for fine-tuning job status updates.
  Updates the local database with the latest status and cost information.
  """

  use Oban.Worker, queue: :fine_tuning, max_attempts: 3

  require Logger
  alias ViralEngine.{FineTuningContext, Integration.OpenAIFineTuning}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_id" => job_id, "api_key" => api_key}}) do
    Logger.info("Polling fine-tuning job status", job_id: job_id)

    case FineTuningContext.get_job(job_id) do
      nil ->
        Logger.error("Fine-tuning job not found in database", job_id: job_id)
        {:error, :job_not_found}

      job ->
        case OpenAIFineTuning.get_fine_tuning_job(job_id, api_key) do
          {:ok, %{"status" => status} = response} ->
            # Update job status and other fields
            updates = %{
              status: map_openai_status(status)
            }

            # Add fine-tuned model ID if completed
            updates =
              if status == "succeeded" do
                case response do
                  %{"fine_tuned_model" => model_id} ->
                    Map.put(updates, :fine_tuned_model_id, model_id)

                  _ ->
                    updates
                end
              else
                updates
              end

            # Add cost information if available
            updates =
              case OpenAIFineTuning.extract_job_cost_info(response) do
                {:ok, cost_info} ->
                  Map.put(updates, :cost, cost_info.total_cost)

                {:error, _} ->
                  updates
              end

            # Add error message if failed
            updates =
              if status == "failed" do
                case response do
                  %{"error" => %{"message" => message}} ->
                    Map.put(updates, :error_message, message)

                  _ ->
                    Map.put(updates, :error_message, "Unknown error")
                end
              else
                updates
              end

            case FineTuningContext.update_job(job, updates) do
              {:ok, _updated_job} ->
                Logger.info("Updated fine-tuning job status",
                  job_id: job_id,
                  status: status,
                  fine_tuned_model_id: updates[:fine_tuned_model_id]
                )

                # If job is completed or failed, don't reschedule
                if status in ["succeeded", "failed", "cancelled"] do
                  :ok
                else
                  # Reschedule for next poll in 30 seconds
                  {:ok, _} = schedule_next_poll(job_id, api_key)
                  :ok
                end

              {:error, changeset} ->
                Logger.error("Failed to update fine-tuning job",
                  job_id: job_id,
                  errors: changeset.errors
                )

                {:error, :update_failed}
            end

          {:error, {:http_error, status, body}} ->
            Logger.warning("OpenAI API error polling job status",
              job_id: job_id,
              status: status,
              body: body
            )

            # If it's a 404, the job might not exist - mark as failed
            if status == 404 do
              FineTuningContext.update_job(job, %{
                status: "failed",
                error_message: "Job not found in OpenAI"
              })

              :ok
            else
              # Retry with exponential backoff
              {:error, :api_error}
            end

          {:error, reason} ->
            Logger.error("Failed to poll fine-tuning job status",
              job_id: job_id,
              reason: reason
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Schedules the next status poll for a fine-tuning job.
  """
  def schedule_next_poll(job_id, api_key) do
    %{job_id: job_id, api_key: api_key}
    # Poll every 30 seconds
    |> new(schedule_in: 30)
    |> Oban.insert()
  end

  @doc """
  Schedules initial status polling for a new fine-tuning job.
  """
  def schedule_initial_poll(job_id, api_key) do
    %{job_id: job_id, api_key: api_key}
    # Start polling in 10 seconds
    |> new(schedule_in: 10)
    |> Oban.insert()
  end

  # Maps OpenAI status to our internal status
  defp map_openai_status("pending"), do: "pending"
  defp map_openai_status("running"), do: "running"
  defp map_openai_status("succeeded"), do: "completed"
  defp map_openai_status("failed"), do: "failed"
  defp map_openai_status("cancelled"), do: "failed"
  defp map_openai_status(status), do: status
end
