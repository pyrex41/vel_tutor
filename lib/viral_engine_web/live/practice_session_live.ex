defmodule ViralEngineWeb.PracticeSessionLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.PracticeContext
  require Logger

  @impl true
  def mount(%{"session_id" => session_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Load existing session from database
    case PracticeContext.get_user_session(session_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> redirect(to: "/dashboard")}

      session ->
        initialize_session(socket, user, session)
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Create a new default practice session
    {:ok, session} =
      PracticeContext.create_session(%{
        user_id: user.id,
        session_type: "practice_test",
        subject: "math",
        total_steps: 5
      })

    # Create sample steps
    sample_steps = [
      {1, %{title: "Warm-up", content: "Review basics", question_type: "open_ended", correct_answer: "correct"}},
      {2, %{title: "Exercise 1", content: "Solve problem A", question_type: "multiple_choice", correct_answer: "B", options: ["A", "B", "C", "D"]}},
      {3, %{title: "Exercise 2", content: "Solve problem B", question_type: "true_false", correct_answer: "true"}},
      {4, %{title: "Review", content: "Check answers", question_type: "open_ended", correct_answer: "correct"}},
      {5, %{title: "Wrap-up", content: "Summary", question_type: "open_ended", correct_answer: "correct"}}
    ]

    {:ok, _steps} = PracticeContext.create_steps(session.id, sample_steps)

    # Reload session with steps
    session = PracticeContext.get_session(session.id)

    initialize_session(socket, user, session)
  end

  defp initialize_session(socket, user, session) do
    if connected?(socket) do
      ViralEngine.PresenceTracker.track_user(socket, user, subject_id: "practice")
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subject:practice")
    end

    # Start timer
    Process.send_after(self(), :tick, 1000)

    socket =
      socket
      |> assign(:session, session)
      |> assign(:steps, session.steps)
      |> assign(:current_step, session.current_step)
      |> assign(:timer, session.timer_seconds)
      |> assign(:paused, session.paused)
      |> assign(:feedback, "")
      |> assign(:user, user)
      |> assign(:practice_users, [])
      |> assign(:loading, false)

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

      # Persist timer state to database every 10 seconds
      if rem(new_timer, 10) == 0 do
        PracticeContext.update_progress(socket.assigns.session.id, %{
          timer_seconds: new_timer
        })
      end

      Process.send_after(self(), :tick, 1000)
      {:noreply, assign(socket, :timer, new_timer)}
    end
  end

  @impl true
  def handle_event("pause", _params, socket) do
    new_paused = !socket.assigns.paused

    # Persist pause state
    PracticeContext.update_progress(socket.assigns.session.id, %{
      paused: new_paused,
      timer_seconds: socket.assigns.timer
    })

    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, :paused, new_paused)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current = socket.assigns.current_step
    total_steps = length(socket.assigns.steps)

    if current < total_steps do
      new_step = current + 1

      # Persist progress
      PracticeContext.update_progress(socket.assigns.session.id, %{
        current_step: new_step,
        timer_seconds: socket.assigns.timer
      })

      {:noreply, assign(socket, :current_step, new_step, :feedback, "")}
    else
      # Session complete
      PracticeContext.complete_session(socket.assigns.session.id)

      {:noreply,
       socket
       |> assign(:feedback, "Session complete! Great job!")
       |> put_flash(:info, "Practice session completed successfully")}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    current = socket.assigns.current_step
    session_id = socket.assigns.session.id

    # Validate and record answer
    case PracticeContext.validate_and_record_answer(session_id, current, answer) do
      {:ok, result} ->
        feedback = result.feedback
        is_correct = result.is_correct

        # Mark step as completed if correct
        if is_correct do
          PracticeContext.complete_step(session_id, current)

          # Auto-advance after 2 seconds
          Process.send_after(self(), :next_after_feedback, 2000)
        end

        {:noreply, assign(socket, :feedback, feedback)}

      {:error, :step_not_found} ->
        {:noreply, assign(socket, :feedback, "Error: Step not found")}

      {:error, _changeset} ->
        {:noreply, assign(socket, :feedback, "Error recording answer. Please try again.")}
    end
  end

  def handle_info(:next_after_feedback, socket) do
    handle_event("next_step", %{}, socket)
  end

  @impl true
  def handle_event("reset_session", _params, socket) do
    session_id = socket.assigns.session.id

    # Reset session progress
    PracticeContext.update_progress(session_id, %{
      current_step: 1,
      timer_seconds: 0,
      paused: false,
      completed: false
    })

    # Reload session
    session = PracticeContext.get_session(session_id)

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:current_step, 1)
     |> assign(:timer, 0)
     |> assign(:paused, false)
     |> assign(:feedback, "Session reset!")
     |> put_flash(:info, "Practice session has been reset")}
  end
end
