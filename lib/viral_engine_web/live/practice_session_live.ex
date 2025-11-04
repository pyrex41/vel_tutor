defmodule ViralEngineWeb.PracticeSessionLive do
  use ViralEngineWeb, :live_view

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    steps = [
      %{id: 1, title: "Warm-up", content: "Review basics", completed: false},
      %{id: 2, title: "Exercise 1", content: "Solve problem A", completed: false},
      %{id: 3, title: "Exercise 2", content: "Solve problem B", completed: false},
      %{id: 4, title: "Review", content: "Check answers", completed: false},
      %{id: 5, title: "Wrap-up", content: "Summary", completed: false}
    ]

    if connected?(socket) do
      ViralEngine.PresenceTracker.track_user(socket, user, subject_id: "practice")
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subject:practice")
    end

    socket =
      socket
      |> assign(:steps, steps)
      |> assign(:current_step, 1)
      |> assign(:timer, 0)
      |> assign(:paused, false)
      |> assign(:feedback, "")
      |> assign(:user, user)
      |> assign(:practice_users, [])

    Process.send_after(self(), :tick, 1000)
    {:ok, socket}
  end

  def handle_info({:presence_diff, _}, socket) do
    users = ViralEngine.Presence.list_subject("practice") |> Map.keys()
    {:noreply, assign(socket, practice_users: users)}
  end

  def handle_info(:tick, socket) do
    if socket.assigns.paused do
      Process.send_after(self(), :tick, 1000)
      {:noreply, socket}
    else
      new_timer = socket.assigns.timer + 1
      Process.send_after(self(), :tick, 1000)
      {:noreply, assign(socket, :timer, new_timer)}
    end
  end

  @impl true
  def handle_event("pause", _params, socket) do
    new_paused = !socket.assigns.paused
    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, :paused, new_paused)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current = socket.assigns.current_step

    steps =
      update_in(
        socket.assigns.steps,
        &List.update_at(&1, current - 1, fn step -> %{step | completed: true} end)
      )

    socket = assign(socket, :steps, steps)

    if current < length(steps) do
      {:noreply, assign(socket, :current_step, current + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    current = socket.assigns.current_step

    feedback =
      if String.length(answer) > 0 and String.contains?(answer, "correct"),
        do: "Correct! Step completed.",
        else: "Try again."

    steps =
      if String.contains?(feedback, "completed"),
        do:
          update_in(
            socket.assigns.steps,
            &List.update_at(&1, current - 1, fn step -> %{step | completed: true} end)
          ),
        else: socket.assigns.steps

    socket = assign(socket, :steps, steps, :feedback, feedback)

    if String.contains?(feedback, "completed") do
      Process.send_after(self(), {:next_after_feedback, 2000})
    end

    {:noreply, socket}
  end

  def handle_info({:next_after_feedback, _}, socket) do
    {:noreply, handle_event("next_step", %{}, socket)}
  end
end
