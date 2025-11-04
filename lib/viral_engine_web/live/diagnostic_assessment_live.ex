defmodule ViralEngineWeb.DiagnosticAssessmentLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.DiagnosticContext
  # alias ViralEngine.DiagnosticAssessment  # Unused - commented for future use
  require Logger

  @impl true
  def mount(%{"id" => assessment_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    case DiagnosticContext.get_user_assessment(assessment_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Assessment not found")
         |> redirect(to: "/dashboard")}

      assessment ->
        initialize_assessment(socket, user, assessment)
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:stage, :subject_selection)
      |> assign(:selected_subject, nil)
      |> assign(:selected_grade, nil)
      |> assign(:assessment, nil)
      |> assign(:current_question, nil)
      |> assign(:feedback, "")
      |> assign(:time_warning, false)
      |> assign(:loading, false)

    {:ok, socket}
  end

  defp initialize_assessment(socket, user, assessment) do
    if assessment.completed do
      # Redirect to results page
      {:ok,
       socket
       |> put_flash(:info, "Assessment already completed")
       |> redirect(to: "/diagnostic/results/#{assessment.id}")}
    else
      # Load current question
      current_question =
        DiagnosticContext.get_question(assessment.id, assessment.current_question)

      # Start timer
      if connected?(socket) do
        Process.send_after(self(), :tick, 1000)
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:stage, :assessment)
        |> assign(:assessment, assessment)
        |> assign(:current_question, current_question)
        |> assign(:feedback, "")
        |> assign(:time_warning, assessment.time_remaining_seconds < 300)
        |> assign(:loading, false)

      {:ok, socket}
    end
  end

  # Timer tick
  def handle_info(:tick, socket) do
    if socket.assigns.stage == :assessment && socket.assigns.assessment do
      assessment = socket.assigns.assessment
      new_time = max(0, assessment.time_remaining_seconds - 1)

      # Update time in database every 10 seconds
      if rem(new_time, 10) == 0 do
        DiagnosticContext.update_time_remaining(assessment.id, new_time)
      end

      # Check for time warning (5 minutes left)
      time_warning = new_time < 300 && new_time > 0

      # Auto-complete if time runs out
      if new_time == 0 do
        DiagnosticContext.complete_assessment(assessment.id)

        {:noreply,
         socket
         |> put_flash(:warning, "Time's up! Assessment completed.")
         |> redirect(to: "/diagnostic/results/#{assessment.id}")}
      else
        Process.send_after(self(), :tick, 1000)

        {:noreply,
         socket
         |> assign(:assessment, %{assessment | time_remaining_seconds: new_time})
         |> assign(:time_warning, time_warning)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_subject", %{"subject" => subject}, socket) do
    {:noreply, assign(socket, :selected_subject, subject)}
  end

  @impl true
  def handle_event("select_grade", %{"grade" => grade}, socket) do
    {:noreply, assign(socket, :selected_grade, grade)}
  end

  @impl true
  def handle_event("start_assessment", _params, socket) do
    subject = socket.assigns.selected_subject
    grade = socket.assigns.selected_grade

    if subject && grade do
      # Create assessment
      {:ok, assessment} =
        DiagnosticContext.create_assessment(%{
          user_id: socket.assigns.user.id,
          subject: subject,
          grade_level: grade,
          total_questions: 20
        })

      # Generate initial questions at medium difficulty (5)
      {:ok, _questions} =
        DiagnosticContext.generate_questions(assessment.id, subject, 5, 1)

      # Reload assessment with questions
      assessment = DiagnosticContext.get_assessment(assessment.id)
      current_question = DiagnosticContext.get_question(assessment.id, 1)

      # Start timer
      Process.send_after(self(), :tick, 1000)

      {:noreply,
       socket
       |> assign(:stage, :assessment)
       |> assign(:assessment, assessment)
       |> assign(:current_question, current_question)
       |> assign(:time_warning, false)
       |> put_flash(:info, "Assessment started! Good luck!")}
    else
      {:noreply, put_flash(socket, :error, "Please select both subject and grade level")}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    assessment = socket.assigns.assessment
    current_question = socket.assigns.current_question

    if assessment && current_question do
      # Record response
      {:ok, response} =
        DiagnosticContext.record_response(%{
          diagnostic_assessment_id: assessment.id,
          diagnostic_question_id: current_question.id,
          user_answer: answer,
          time_spent_seconds: current_question.time_allocated_seconds - assessment.time_remaining_seconds
        })

      # Show feedback
      feedback = if response.is_correct, do: "Correct!", else: "Incorrect"

      # Advance to next question after brief delay
      Process.send_after(self(), :advance_question, 1500)

      {:noreply,
       socket
       |> assign(:feedback, feedback)
       |> assign(:loading, true)}
    else
      {:noreply, put_flash(socket, :error, "Error submitting answer")}
    end
  end

  def handle_info(:advance_question, socket) do
    assessment = socket.assigns.assessment

    if assessment.current_question >= assessment.total_questions do
      # Assessment complete
      DiagnosticContext.complete_assessment(assessment.id)

      {:noreply,
       socket
       |> put_flash(:success, "Assessment completed!")
       |> redirect(to: "/diagnostic/results/#{assessment.id}")}
    else
      # Advance question
      {:ok, updated_assessment} = DiagnosticContext.advance_question(assessment.id)

      # Load next question
      next_question =
        DiagnosticContext.get_question(updated_assessment.id, updated_assessment.current_question)

      {:noreply,
       socket
       |> assign(:assessment, updated_assessment)
       |> assign(:current_question, next_question)
       |> assign(:feedback, "")
       |> assign(:loading, false)}
    end
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    # Record as incorrect and advance
    handle_event("submit_answer", %{"answer" => ""}, socket)
  end

  @impl true
  def handle_event("pause_assessment", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Assessment paused. You can resume anytime.")
     |> redirect(to: "/dashboard")}
  end

  # Helper functions

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end
end
