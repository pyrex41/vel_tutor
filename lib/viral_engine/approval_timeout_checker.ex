defmodule ViralEngine.ApprovalTimeoutChecker do
  use GenServer
  require Logger
  alias ViralEngine.{WorkflowContext, Repo}
  alias ViralEngine.Workflow
  import Ecto.Query

  # Check every 5 minutes
  @check_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting ApprovalTimeoutChecker")
    schedule_check()
    {:ok, %{}}
  end

  def handle_info(:check_timeouts, state) do
    check_all_timeouts()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_timeouts, @check_interval)
  end

  defp check_all_timeouts do
    Logger.info("Checking for timed-out approval workflows")

    # Find all workflows awaiting approval
    awaiting_workflows =
      from(w in Workflow, where: w.status == "awaiting_approval")
      |> Repo.all()

    Enum.each(awaiting_workflows, fn workflow ->
      case WorkflowContext.check_timeout(workflow.id) do
        {:ok, {:timed_out, _updated_workflow}} ->
          Logger.info(
            "Workflow #{workflow.id} (#{workflow.name}) timed out and was auto-rejected"
          )

        {:ok, _} ->
          # Not timed out, continue
          :ok

        {:error, reason} ->
          Logger.error("Error checking timeout for workflow #{workflow.id}: #{inspect(reason)}")
      end
    end)
  end

  # Public API for manual timeout checks
  def check_now do
    GenServer.call(__MODULE__, :check_now)
  end

  def handle_call(:check_now, _from, state) do
    check_all_timeouts()
    {:reply, :ok, state}
  end
end
