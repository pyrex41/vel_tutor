defmodule ViralEngine.Jobs.ProcessFineTuningJob do
  @moduledoc """
  Background job to process a fine-tuning job from start to finish.
  Handles file upload, job creation, and initiates status polling.
  """

  use Oban.Worker, queue: :fine_tuning, max_attempts: 1

  require Logger
  alias ViralEngine.{FineTuningContext, Integration.OpenAIFineTuning, Jobs.PollFineTuningStatus}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_id" => job_id, "api_key" => api_key}}) do
    Logger.info("Processing fine-tuning job", job_id: job_id)

    case FineTuningContext.get_job(job_id) do
      nil ->
        Logger.error("Fine-tuning job not found in database", job_id: job_id)
        {:error, :job_not_found}

      %{training_file_id: nil, status: "pending"} = job ->
        # Job needs file upload first
        handle_file_upload(job, api_key)

      %{training_file_id: file_id, status: "pending"} = job when not is_nil(file_id) ->
        # File already uploaded, create the fine-tuning job
        handle_job_creation(job, api_key)

      job ->
        Logger.info("Job already processed or in progress",
          job_id: job_id,
          status: job.status
        )

        :ok
    end
  end

  @doc """
  Schedules processing for a new fine-tuning job.
  """
  def schedule_processing(job_id, api_key) do
    %{job_id: job_id, api_key: api_key}
    |> new()
    |> Oban.insert()
  end

  # Private functions

  defp handle_file_upload(job, api_key) do
    # For now, we assume the training file is already provided as a path or URL
    # In a real implementation, you might need to handle file uploads from users
    Logger.warning("File upload not implemented - training_file_id should be set",
      job_id: job.id
    )

    # Mark as failed for now
    FineTuningContext.update_job(job, %{
      status: "failed",
      error_message: "File upload not implemented"
    })

    {:error, :file_upload_not_implemented}
  end

  defp handle_job_creation(job, api_key) do
    Logger.info("Creating OpenAI fine-tuning job",
      job_id: job.id,
      model: job.model,
      training_file_id: job.training_file_id
    )

    case OpenAIFineTuning.create_fine_tuning_job(
           job.training_file_id,
           job.model,
           api_key
         ) do
      {:ok, %{job_id: openai_job_id}} ->
        Logger.info("OpenAI fine-tuning job created successfully",
          local_job_id: job.id,
          openai_job_id: openai_job_id
        )

        # Update our job with the OpenAI job ID (assuming we store it in fine_tuned_model_id temporarily)
        # In a real implementation, you might want a separate field for openai_job_id
        case FineTuningContext.update_job(job, %{
               status: "running",
               # Temporary storage
               fine_tuned_model_id: openai_job_id
             }) do
          {:ok, _} ->
            # Schedule status polling
            case PollFineTuningStatus.schedule_initial_poll(openai_job_id, api_key) do
              {:ok, _} ->
                Logger.info("Status polling scheduled", openai_job_id: openai_job_id)
                :ok

              {:error, reason} ->
                Logger.error("Failed to schedule status polling",
                  openai_job_id: openai_job_id,
                  reason: reason
                )

                # Don't fail the job for this
                :ok
            end

          {:error, changeset} ->
            Logger.error("Failed to update job with OpenAI job ID",
              job_id: job.id,
              errors: changeset.errors
            )

            {:error, :update_failed}
        end

      {:error, {:http_error, status, body}} ->
        Logger.error("OpenAI API error creating fine-tuning job",
          job_id: job.id,
          status: status,
          body: body
        )

        error_message = extract_error_message(body)

        FineTuningContext.update_job(job, %{
          status: "failed",
          error_message: error_message
        })

        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Failed to create OpenAI fine-tuning job",
          job_id: job.id,
          reason: reason
        )

        FineTuningContext.update_job(job, %{
          status: "failed",
          error_message: "Failed to create fine-tuning job: #{inspect(reason)}"
        })

        {:error, reason}
    end
  end

  defp extract_error_message(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} ->
        message

      _ ->
        "Unknown API error"
    end
  rescue
    _ -> "Unknown API error"
  end
end
