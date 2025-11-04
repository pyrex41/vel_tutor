defmodule ViralEngine.Workers.PerformanceReportWorker do
  @moduledoc """
  Oban worker for generating weekly viral loop performance reports.

  Scheduled to run every Monday at 9:00 AM UTC to generate reports for the previous week.

  ## Configuration

  Add to your config/config.exs:

  ```
  config :viral_engine, Oban,
    queues: [performance_reports: 1],
    plugins: [
      {Oban.Plugins.Cron,
        crontab: [
          # Generate weekly report every Monday at 9:00 AM
          {"0 9 * * 1", ViralEngine.Workers.PerformanceReportWorker, args: %{type: "weekly"}},
          # Generate monthly report on 1st of each month at 10:00 AM
          {"0 10 1 * *", ViralEngine.Workers.PerformanceReportWorker, args: %{type: "monthly"}}
        ]}
    ]
  ```

  ## Manual Trigger

  Generate report immediately:

  ```
  %{type: "weekly", recipients: ["admin@example.com"]}
  |> ViralEngine.Workers.PerformanceReportWorker.new()
  |> Oban.insert()
  ```
  """

  use Oban.Worker,
    queue: :performance_reports,
    max_attempts: 3

  alias ViralEngine.PerformanceReportContext
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => report_type} = args}) do
    Logger.info("Starting performance report generation: #{report_type}")

    # Determine date range based on report type
    {start_date, end_date} = case report_type do
      "weekly" ->
        # Previous full week (Monday to Sunday)
        end_date = Date.add(Date.utc_today(), -1)  # Yesterday
        start_date = Date.add(end_date, -6)  # 7 days ago
        {start_date, end_date}

      "monthly" ->
        # Previous full month
        today = Date.utc_today()
        first_of_month = %{today | day: 1}
        end_date = Date.add(first_of_month, -1)  # Last day of previous month
        start_date = %{end_date | day: 1}  # First day of previous month
        {start_date, end_date}

      "custom" ->
        # Custom date range from args
        start_date = args["start_date"] |> parse_date()
        end_date = args["end_date"] |> parse_date()
        {start_date, end_date}

      _ ->
        # Default to last 7 days
        end_date = Date.utc_today()
        start_date = Date.add(end_date, -7)
        {start_date, end_date}
    end

    # Generate the report
    case PerformanceReportContext.generate_weekly_report(
      start_date: start_date,
      end_date: end_date
    ) do
      {:ok, report} ->
        Logger.info("Successfully generated report #{report.id} for #{start_date} to #{end_date}")

        # Deliver report if recipients specified
        recipients = args["recipients"] || default_recipients()

        if recipients && length(recipients) > 0 do
          case PerformanceReportContext.deliver_report(report.id, recipients) do
            {:ok, _} ->
              Logger.info("Report #{report.id} delivered to #{inspect(recipients)}")
              :ok

            {:error, reason} ->
              Logger.error("Failed to deliver report #{report.id}: #{inspect(reason)}")
              {:error, reason}
          end
        else
          Logger.info("No recipients specified for report #{report.id}, skipping delivery")
          :ok
        end

      {:error, reason} ->
        Logger.error("Failed to generate performance report: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedules a weekly report generation.
  """
  def schedule_weekly_report(recipients \\ []) do
    %{type: "weekly", recipients: recipients}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Schedules a monthly report generation.
  """
  def schedule_monthly_report(recipients \\ []) do
    %{type: "monthly", recipients: recipients}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Schedules a custom date range report.
  """
  def schedule_custom_report(start_date, end_date, recipients \\ []) do
    %{
      type: "custom",
      start_date: Date.to_string(start_date),
      end_date: Date.to_string(end_date),
      recipients: recipients
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  # Private helpers

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> Date.utc_today()
    end
  end
  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: Date.utc_today()

  defp default_recipients do
    # In production, fetch from config or database
    # Application.get_env(:viral_engine, :report_recipients, [])
    []
  end
end
