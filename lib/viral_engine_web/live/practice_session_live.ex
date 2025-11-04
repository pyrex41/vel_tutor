defmodule ViralEngineWeb.PracticeSessionLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{PracticeContext, ViralPrompts, ChallengeContext}
  require Logger

  on_mount ViralEngineWeb.Live.ViralPromptsHook

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
      |> assign(:user_id, user.id)
      |> assign(:practice_users, [])
      |> assign(:loading, false)
      |> assign(:viral_prompt, nil)
      |> assign(:show_viral_modal, false)

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
      {:ok, completed_session} = PracticeContext.complete_session(socket.assigns.session.id)

      # Check if this was a buddy challenge session
      if completed_session.metadata["challenge_id"] do
        handle_challenge_completion(completed_session)
      end

      # Trigger viral prompt (only if not a challenge session)
      viral_prompt = if completed_session.metadata["challenge_id"] do
        nil  # Don't show viral prompt for challenge sessions
      else
        trigger_completion_prompt(socket.assigns.user_id, completed_session)
      end

      socket =
        socket
        |> assign(:feedback, "Session complete! Great job!")
        |> assign(:viral_prompt, viral_prompt)
        |> assign(:show_viral_modal, viral_prompt != nil)
        |> put_flash(:info, "Practice session completed successfully")

      {:noreply, socket}
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

  @impl true
  def handle_event("close_viral_modal", _params, socket) do
    {:noreply, assign(socket, :show_viral_modal, false)}
  end

  @impl true
  def handle_event("viral_prompt_clicked", %{"prompt_log_id" => log_id}, socket) do
    # Record click
    if log_id do
      ViralPrompts.record_click(String.to_integer(log_id))
    end

    # Close modal and handle viral action (e.g., share, challenge)
    {:noreply,
     socket
     |> assign(:show_viral_modal, false)
     |> put_flash(:info, "Let's share your results!")}
  end

  # Private helper functions

  defp trigger_completion_prompt(user_id, session) do
    event_data = %{
      session_id: session.id,
      score: session.score || 0,
      subject: session.subject,
      session_type: session.session_type
    }

    case ViralPrompts.trigger_prompt(:practice_completed, user_id, event_data) do
      {:ok, prompt} ->
        # Broadcast event for analytics
        ViralPrompts.broadcast_event(:practice_completed, user_id, event_data)
        prompt

      {:throttled, reason} ->
        Logger.info("Viral prompt throttled for user #{user_id}: #{reason}")
        nil

      {:no_prompt, reason} ->
        Logger.info("No viral prompt for user #{user_id}: #{reason}")
        # Fallback to default prompt
        ViralPrompts.get_default_prompt(:practice_completed)
    end
  end

  defp handle_challenge_completion(session) do
    # Complete the buddy challenge
    challenge_id = session.metadata["challenge_id"]

    Task.start(fn ->
      case ChallengeContext.complete_challenge(challenge_id, session.id) do
        {:ok, challenge} ->
          Logger.info("Buddy challenge #{challenge_id} completed! Winner: #{challenge.winner_id}")

        {:error, reason} ->
          Logger.error("Failed to complete challenge #{challenge_id}: #{reason}")
      end
    end)
  end
end
