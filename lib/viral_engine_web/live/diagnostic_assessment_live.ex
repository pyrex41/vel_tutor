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
  @impl true
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
          time_spent_seconds:
            current_question.time_allocated_seconds - assessment.time_remaining_seconds
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
        <%= if @stage == :subject_selection do %>
          <!-- Subject Selection Stage -->
          <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8">
            <div class="text-center mb-8">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-muted mb-4">
                <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-label="Assessment icon">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                </svg>
              </div>
              <h1 class="text-4xl font-bold text-foreground mb-2">Diagnostic Assessment</h1>
              <p class="text-muted-foreground text-lg">Discover your learning level and get personalized recommendations</p>
            </div>

            <!-- Subject Selection -->
            <div class="mb-8">
              <h2 class="text-xl font-semibold text-foreground mb-4">Select Subject</h2>
              <div class="grid md:grid-cols-3 gap-4">
                <%= for subject <- ["math", "science", "english"] do %>
                  <button
                    phx-click="select_subject"
                    phx-value-subject={subject}
                    class={"p-6 rounded-lg border transition-all duration-200 hover:shadow-sm #{if @selected_subject == subject, do: "border-primary bg-accent shadow-sm ring-2 ring-ring", else: "border-border hover:border-primary"}"}
                    aria-pressed={@selected_subject == subject}
                  >
                    <div class="text-2xl mb-2 text-primary">
                      <%= case subject do %>
                        <% "math" -> %>M
                        <% "science" -> %>S
                        <% "english" -> %>E
                      <% end %>
                    </div>
                    <h3 class="text-lg font-bold text-foreground capitalize"><%= subject %></h3>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Grade Selection -->
            <%= if @selected_subject do %>
              <div class="mb-8">
                <h2 class="text-xl font-semibold text-foreground mb-4">Select Grade Level</h2>
                <div class="grid grid-cols-4 md:grid-cols-6 gap-3">
                  <%= for grade <- 6..12 do %>
                    <button
                      phx-click="select_grade"
                      phx-value-grade={grade}
                      class={"px-4 py-3 rounded-lg border font-semibold transition-all duration-200 #{if @selected_grade == Integer.to_string(grade), do: "border-primary bg-primary text-primary-foreground shadow-sm", else: "border-border text-foreground hover:border-primary hover:bg-accent"}"}
                      aria-pressed={@selected_grade == Integer.to_string(grade)}
                    >
                      <%= grade %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Start Button -->
            <%= if @selected_subject && @selected_grade do %>
              <button
                phx-click="start_assessment"
                class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
                aria-label="Start diagnostic assessment"
              >
                <div class="flex items-center justify-center space-x-2">
                  <span class="text-lg">Start Assessment</span>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                  </svg>
                </div>
              </button>
            <% end %>

            <!-- Info Cards -->
            <div class="mt-8 grid md:grid-cols-3 gap-4">
              <div class="bg-muted rounded-lg p-4 border">
                <div class="flex items-center space-x-3">
                  <div class="flex-shrink-0">
                    <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-muted-foreground">Duration</p>
                    <p class="text-lg font-bold text-foreground">20 minutes</p>
                  </div>
                </div>
              </div>
              <div class="bg-muted rounded-lg p-4 border">
                <div class="flex items-center space-x-3">
                  <div class="flex-shrink-0">
                    <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-muted-foreground">Questions</p>
                    <p class="text-lg font-bold text-foreground">20 total</p>
                  </div>
                </div>
              </div>
              <div class="bg-muted rounded-lg p-4 border">
                <div class="flex items-center space-x-3">
                  <div class="flex-shrink-0">
                    <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-muted-foreground">Adaptive</p>
                    <p class="text-lg font-bold text-foreground">Smart difficulty</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @stage == :assessment && @assessment && @current_question do %>
          <!-- Assessment Stage -->
          <div class="mb-6">
            <!-- Header with Timer and Progress -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <h2 class="text-2xl font-bold text-foreground"><%= String.capitalize(@assessment.subject) %> Assessment</h2>
                  <p class="text-muted-foreground">Question <%= @assessment.current_question %> of <%= @assessment.total_questions %></p>
                </div>
                <div class="text-right">
                  <div class={"text-3xl font-mono font-bold #{if @time_warning, do: "text-destructive animate-pulse", else: "text-primary"}"} aria-live="polite">
                    <%= format_time(@assessment.time_remaining_seconds) %>
                  </div>
                  <%= if @time_warning do %>
                    <p class="text-sm text-destructive font-medium" aria-live="assertive">Time running out!</p>
                  <% else %>
                    <p class="text-sm text-muted-foreground">Time remaining</p>
                  <% end %>
                </div>
              </div>

              <!-- Progress Bar -->
              <div class="relative" role="progressbar" aria-valuenow={@assessment.current_question} aria-valuemin="1" aria-valuemax={@assessment.total_questions} aria-label="Assessment progress">
                <div class="w-full bg-secondary rounded-full h-3 overflow-hidden">
                  <div
                    class="bg-primary h-3 rounded-full transition-all duration-500 ease-out"
                    style={"width: #{(@assessment.current_question / @assessment.total_questions) * 100}%"}
                  >
                  </div>
                </div>
              </div>
            </div>

            <!-- Question Card -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-6">
              <!-- Difficulty Indicator -->
              <div class="flex items-center justify-between mb-6">
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-muted text-muted-foreground">
                  <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
                  </svg>
                  Difficulty: <%= @current_question.difficulty || 5 %>/10
                </span>
                <div class="flex items-center space-x-2">
                  <button
                    phx-click="skip_question"
                    class="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
                    disabled={@loading}
                    aria-label="Skip this question"
                  >
                    Skip →
                  </button>
                  <button
                    phx-click="pause_assessment"
                    class="text-muted-foreground hover:text-foreground text-sm font-medium transition-colors"
                    aria-label="Pause assessment"
                  >
                    Pause
                  </button>
                </div>
              </div>

              <!-- Question Text -->
              <div class="mb-8">
                <h3 class="text-2xl font-semibold text-foreground mb-4 leading-relaxed">
                  <%= @current_question.question_text %>
                </h3>
              </div>

              <!-- Answer Options -->
              <%= if !@loading do %>
                <form phx-submit="submit_answer" class="space-y-3">
                  <%= if @current_question.question_type == "multiple_choice" && @current_question.options do %>
                    <fieldset class="space-y-3">
                      <legend class="sr-only">Choose your answer</legend>
                      <%= for {option, index} <- Enum.with_index(@current_question.options) do %>
                        <label class="flex items-start p-4 border border-border rounded-lg hover:border-primary hover:bg-accent cursor-pointer transition-all duration-200 group">
                          <input
                            type="radio"
                            name="answer"
                            value={option}
                            class="mt-1 w-5 h-5 text-primary focus:ring-ring"
                            required
                            aria-describedby={"option-#{index}"}
                          />
                          <div class="ml-3 flex-1">
                            <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-muted text-muted-foreground text-sm font-bold mr-2 group-hover:bg-accent group-hover:text-accent-foreground" id={"option-#{index}"}>
                              <%= String.at("ABCD", index) %>
                            </span>
                            <span class="text-foreground font-medium"><%= option %></span>
                          </div>
                        </label>
                      <% end %>
                    </fieldset>
                  <% else %>
                    <div class="relative">
                      <input
                        type="text"
                        name="answer"
                        placeholder="Type your answer here..."
                        class="w-full px-4 py-3 border border-input rounded-lg focus:ring-2 focus:ring-ring focus:border-input transition-all duration-200 text-lg bg-background"
                        required
                        autofocus
                        aria-label="Answer input"
                      />
                    </div>
                  <% end %>

                  <button
                    type="submit"
                    class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
                    aria-label="Submit your answer"
                  >
                    Submit Answer
                  </button>
                </form>
              <% end %>

              <!-- Feedback -->
              <%= if @feedback != "" do %>
                <div class={"mt-6 p-4 rounded-lg border #{if String.contains?(@feedback, "Correct"), do: "bg-green-50 border-green-300 text-green-900", else: "bg-red-50 border-red-300 text-red-900"}"} role="alert" aria-live="polite">
                  <div class="flex items-center space-x-3">
                    <%= if String.contains?(@feedback, "Correct") do %>
                      <svg class="w-6 h-6 text-green-600 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                      <p class="font-semibold"><%= @feedback %></p>
                    <% else %>
                      <svg class="w-6 h-6 text-red-600 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                      </svg>
                      <p class="font-semibold"><%= @feedback %></p>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Loading Indicator -->
              <%= if @loading do %>
                <div class="mt-6 flex items-center justify-center space-x-2 text-primary" aria-live="polite">
                  <svg class="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24" aria-hidden="true">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span class="font-medium">Loading next question...</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
