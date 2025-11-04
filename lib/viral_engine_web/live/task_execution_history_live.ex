defmodule ViralEngineWeb.TaskExecutionHistoryLive do
  @moduledoc """
  LiveView dashboard for exploring task execution history with filtering, search, and analytics.
  """

  use Phoenix.LiveView
  alias ViralEngine.{Task, Repo}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to task updates for real-time updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "tasks")
    end

    # Initial data load
    tasks = list_tasks()
    analytics = calculate_analytics()

    socket =
      socket
      |> assign(:tasks, tasks)
      |> assign(:analytics, analytics)
      |> assign(:filter_status, "all")
      |> assign(:filter_agent, "all")
      |> assign(:filter_user, "")
      |> assign(:search_query, "")
      |> assign(:date_from, "")
      |> assign(:date_to, "")
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:total_pages, calculate_total_pages())

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_status = params["status"] || "all"
    filter_agent = params["agent"] || "all"
    filter_user = params["user"] || ""
    search_query = params["search"] || ""
    date_from = params["date_from"] || ""
    date_to = params["date_to"] || ""
    page = String.to_integer(params["page"] || "1")

    tasks =
      list_tasks(
        filter_status: filter_status,
        filter_agent: filter_agent,
        filter_user: filter_user,
        search_query: search_query,
        date_from: date_from,
        date_to: date_to,
        page: page,
        page_size: socket.assigns.page_size
      )

    socket =
      socket
      |> assign(:tasks, tasks)
      |> assign(:filter_status, filter_status)
      |> assign(:filter_agent, filter_agent)
      |> assign(:filter_user, filter_user)
      |> assign(:search_query, search_query)
      |> assign(:date_from, date_from)
      |> assign(:date_to, date_to)
      |> assign(:page, page)
      |> assign(
        :total_pages,
        calculate_total_pages(
          filter_status: filter_status,
          filter_agent: filter_agent,
          filter_user: filter_user,
          search_query: search_query,
          date_from: date_from,
          date_to: date_to
        )
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query_params = %{
      "status" => params["status"] || "all",
      "agent" => params["agent"] || "all",
      "user" => params["user"] || "",
      "search" => params["search"] || "",
      "date_from" => params["date_from"] || "",
      "date_to" => params["date_to"] || "",
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: "/dashboard/tasks?" <> URI.encode_query(query_params))}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: "/dashboard/tasks")}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    page_num = String.to_integer(page)

    current_params = %{
      "status" => socket.assigns.filter_status,
      "agent" => socket.assigns.filter_agent,
      "user" => socket.assigns.filter_user,
      "search" => socket.assigns.search_query,
      "date_from" => socket.assigns.date_from,
      "date_to" => socket.assigns.date_to,
      "page" => to_string(page_num)
    }

    {:noreply, push_patch(socket, to: "/dashboard/tasks?" <> URI.encode_query(current_params))}
  end

  @impl true
  def handle_info({:task_updated, task_id}, socket) do
    # Refresh the specific task in the list
    updated_tasks =
      Enum.map(socket.assigns.tasks, fn
        %{id: ^task_id} = task ->
          Repo.get(Task, task_id)

        task ->
          task
      end)

    analytics = calculate_analytics()

    socket =
      socket
      |> assign(:tasks, updated_tasks)
      |> assign(:analytics, analytics)

    {:noreply, socket}
  end

  # Private functions

  defp list_tasks(opts \\ []) do
    filter_status = Keyword.get(opts, :filter_status, "all")
    filter_agent = Keyword.get(opts, :filter_agent, "all")
    filter_user = Keyword.get(opts, :filter_user, "")
    search_query = Keyword.get(opts, :search_query, "")
    date_from = Keyword.get(opts, :date_from, "")
    date_to = Keyword.get(opts, :date_to, "")
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    offset = (page - 1) * page_size

    query =
      from(t in Task,
        order_by: [desc: t.inserted_at],
        limit: ^page_size,
        offset: ^offset
      )

    query =
      apply_filters(query, %{
        status: filter_status,
        agent: filter_agent,
        user: filter_user,
        search: search_query,
        date_from: date_from,
        date_to: date_to
      })

    Repo.all(query)
  end

  defp apply_filters(query, filters) do
    query
    |> filter_by_status(filters.status)
    |> filter_by_agent(filters.agent)
    |> filter_by_user(filters.user)
    |> filter_by_search(filters.search)
    |> filter_by_date_range(filters.date_from, filters.date_to)
  end

  defp filter_by_status(query, "all"), do: query
  defp filter_by_status(query, status), do: from(t in query, where: t.status == ^status)

  defp filter_by_agent(query, "all"), do: query
  defp filter_by_agent(query, agent), do: from(t in query, where: t.agent_id == ^agent)

  defp filter_by_user(query, ""), do: query

  defp filter_by_user(query, user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> from(t in query, where: t.user_id == ^id)
      _ -> query
    end
  end

  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_pattern = "%#{search}%"

    from(t in query,
      where:
        ilike(t.description, ^search_pattern) or
          ilike(t.agent_id, ^search_pattern) or
          ilike(t.error_message, ^search_pattern)
    )
  end

  defp filter_by_date_range(query, "", ""), do: query

  defp filter_by_date_range(query, date_from, date_to) do
    query
    |> filter_date_from(date_from)
    |> filter_date_to(date_to)
  end

  defp filter_date_from(query, "") do
    # Get start of today if no date specified
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])
    from(t in query, where: t.inserted_at >= ^today_start)
  end

  defp filter_date_from(query, date_from) do
    case Date.from_iso8601(date_from) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[00:00:00])
        from(t in query, where: t.inserted_at >= ^datetime)

      _ ->
        query
    end
  end

  defp filter_date_to(query, "") do
    # Get end of today if no date specified
    today_end = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[23:59:59])
    from(t in query, where: t.inserted_at <= ^today_end)
  end

  defp filter_date_to(query, date_to) do
    case Date.from_iso8601(date_to) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[23:59:59])
        from(t in query, where: t.inserted_at <= ^datetime)

      _ ->
        query
    end
  end

  defp calculate_total_pages(opts \\ []) do
    filter_status = Keyword.get(opts, :filter_status, "all")
    filter_agent = Keyword.get(opts, :filter_agent, "all")
    filter_user = Keyword.get(opts, :filter_user, "")
    search_query = Keyword.get(opts, :search_query, "")
    date_from = Keyword.get(opts, :date_from, "")
    date_to = Keyword.get(opts, :date_to, "")

    query = from(t in Task)

    query =
      apply_filters(query, %{
        status: filter_status,
        agent: filter_agent,
        user: filter_user,
        search: search_query,
        date_from: date_from,
        date_to: date_to
      })

    total_count = Repo.aggregate(query, :count)
    page_size = 25
    max(1, ceil(total_count / page_size))
  end

  defp calculate_analytics do
    # Calculate various analytics for the dashboard
    total_tasks = Repo.aggregate(from(t in Task), :count)

    completed_tasks =
      Repo.aggregate(
        from(t in Task, where: t.status == "completed"),
        :count
      )

    failed_tasks =
      Repo.aggregate(
        from(t in Task, where: t.status == "failed"),
        :count
      )

    avg_latency =
      Repo.one(
        from(t in Task,
          where: not is_nil(t.latency_ms),
          select: avg(t.latency_ms)
        )
      ) || 0

    total_cost =
      Repo.one(
        from(t in Task,
          where: not is_nil(t.cost),
          select: sum(t.cost)
        )
      ) || Decimal.new(0)

    success_rate =
      if total_tasks > 0 do
        completed_tasks / total_tasks * 100
      else
        0
      end

    # Recent activity (last 24 hours)
    yesterday = DateTime.add(DateTime.utc_now(), -86400)

    recent_tasks =
      Repo.aggregate(
        from(t in Task, where: t.inserted_at >= ^yesterday),
        :count
      )

    %{
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      failed_tasks: failed_tasks,
      success_rate: success_rate,
      avg_latency: round(avg_latency),
      total_cost: Decimal.to_float(total_cost),
      recent_tasks: recent_tasks
    }
  end

  # Helper functions for templates
  def format_duration(nil), do: "N/A"

  def format_duration(ms) when is_integer(ms) do
    cond do
      ms < 1000 -> "#{ms}ms"
      ms < 60000 -> "#{round(ms / 1000)}s"
      true -> "#{round(ms / 60000)}m #{round(rem(ms, 60000) / 1000)}s"
    end
  end

  def format_cost(nil), do: "N/A"

  def format_cost(cost) do
    "$#{Decimal.to_float(cost) |> Float.round(4)}"
  end

  def status_color("completed"), do: "text-green-600"
  def status_color("failed"), do: "text-red-600"
  def status_color("in_progress"), do: "text-blue-600"
  def status_color("pending"), do: "text-gray-600"
  def status_color(_), do: "text-gray-600"

  def status_badge_class("completed"), do: "bg-green-100 text-green-800"
  def status_badge_class("failed"), do: "bg-red-100 text-red-800"
  def status_badge_class("in_progress"), do: "bg-blue-100 text-blue-800"
  def status_badge_class("pending"), do: "bg-gray-100 text-gray-800"
  def status_badge_class(_), do: "bg-gray-100 text-gray-800"

  def success_rate_color(rate) do
    if rate >= 95, do: "text-green-600", else: "text-orange-600"
  end
end
