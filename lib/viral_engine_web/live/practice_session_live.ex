defmodule ViralEngineWeb.PracticeSessionLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{PracticeContext, ViralPrompts, ChallengeContext, StreakContext, BadgeContext, XPContext}
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

  @impl true
  def handle_info({:presence_diff, _}, socket) do
    users = ViralEngine.Presence.list_subject("practice") |> Map.keys()
    {:noreply, assign(socket, practice_users: users)}
  end

  @impl true
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
  def handle_info(:next_after_feedback, socket) do
    handle_event("next_step", %{}, socket)
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

      {:noreply, assign(socket, current_step: new_step, feedback: "")}
    else
      # Session complete
      {:ok, completed_session} = PracticeContext.complete_session(socket.assigns.session.id)

      # Record activity for streak tracking
      StreakContext.record_activity(socket.assigns.user_id)

      # Grant XP for completing session (async)
      Task.start(fn ->
        base_xp = 50  # Base XP for completing a session
        score_bonus = round((completed_session.score || 0) / 2)  # Bonus XP based on score
        XPContext.grant_xp(socket.assigns.user_id, base_xp + score_bonus, :practice_session)
      end)

      # Check for badge unlocks (async)
      Task.start(fn ->
        BadgeContext.check_and_unlock_badges(socket.assigns.user_id, :practice_completed)
      end)

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <h1 class="text-3xl font-bold text-gray-900">Practice Session</h1>
            <div class="flex items-center gap-4">
              <!-- Active Users -->
              <div class="flex items-center gap-2 text-sm text-gray-600">
                <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z"/>
                </svg>
                <span><%= length(@practice_users) %> online</span>
              </div>

              <!-- Timer -->
              <div class="flex items-center gap-2 bg-white border border-gray-200 rounded-lg px-4 py-2">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span class="font-mono text-lg font-semibold text-gray-900">
                  <%= format_time(@timer) %>
                </span>
              </div>
            </div>
          </div>

          <!-- Progress Bar -->
          <div class="relative">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-700">
                Step <%= @current_step %> of <%= length(@steps) %>
              </span>
              <span class="text-sm text-gray-600">
                <%= round((@current_step / length(@steps)) * 100) %>% Complete
              </span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-blue-500 to-blue-600 transition-all duration-500 ease-out rounded-full"
                style={"width: #{(@current_step / length(@steps)) * 100}%"}
              >
              </div>
            </div>
          </div>
        </div>

        <!-- Main Content -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm">
          <%= if @current_step <= length(@steps) do %>
            <div class="p-8">
              <% step = Enum.at(@steps, @current_step - 1) %>

              <!-- Step Title -->
              <div class="mb-6">
                <h2 class="text-2xl font-bold text-gray-900 mb-2"><%= step.title %></h2>
                <div class="w-16 h-1 bg-blue-600 rounded-full"></div>
              </div>

              <!-- Step Content -->
              <div class="prose prose-lg max-w-none mb-8">
                <p class="text-gray-700"><%= step.content %></p>
              </div>

              <!-- Answer Section -->
              <.form :let={f} for={%{}} as={:answer} phx-submit="submit_answer" class="space-y-6">
                <%= cond do %>
                  <% step.question_type == "multiple_choice" -> %>
                    <div class="space-y-3">
                      <%= for option <- step.options do %>
                        <label class="flex items-center p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition-colors">
                          <input type="radio" name="answer" value={option} class="w-5 h-5 text-blue-600" />
                          <span class="ml-3 text-gray-900 font-medium"><%= option %></span>
                        </label>
                      <% end %>
                    </div>

                  <% step.question_type == "true_false" -> %>
                    <div class="flex gap-4">
                      <label class="flex-1 flex items-center justify-center p-6 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition-colors">
                        <input type="radio" name="answer" value="true" class="w-5 h-5 text-blue-600 mr-3" />
                        <span class="text-lg font-semibold text-gray-900">True</span>
                      </label>
                      <label class="flex-1 flex items-center justify-center p-6 border-2 border-gray-200 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition-colors">
                        <input type="radio" name="answer" value="false" class="w-5 h-5 text-blue-600 mr-3" />
                        <span class="text-lg font-semibold text-gray-900">False</span>
                      </label>
                    </div>

                  <% true -> %>
                    <div>
                      <textarea
                        name="answer"
                        rows="4"
                        class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                        placeholder="Type your answer here..."
                      ></textarea>
                    </div>
                <% end %>

                <!-- Feedback -->
                <%= if @feedback != "" do %>
                  <div class={[
                    "p-4 rounded-lg border-2 flex items-start gap-3",
                    if(String.contains?(@feedback, "Correct") or String.contains?(@feedback, "complete"),
                      do: "bg-green-50 border-green-200 text-green-800",
                      else: "bg-red-50 border-red-200 text-red-800")
                  ]}>
                    <svg class="w-6 h-6 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                      <%= if String.contains?(@feedback, "Correct") or String.contains?(@feedback, "complete") do %>
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                      <% else %>
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                      <% end %>
                    </svg>
                    <div class="font-medium"><%= @feedback %></div>
                  </div>
                <% end %>

                <!-- Actions -->
                <div class="flex gap-3">
                  <button
                    type="submit"
                    class="flex-1 inline-flex items-center justify-center px-6 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                  >
                    Submit Answer
                  </button>

                  <button
                    type="button"
                    phx-click="next_step"
                    class="px-6 py-3 border border-gray-300 text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                  >
                    Skip
                  </button>

                  <button
                    type="button"
                    phx-click="pause"
                    class="px-6 py-3 border border-gray-300 rounded-lg text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                  >
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @paused do %>
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>
                      <% else %>
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/>
                      <% end %>
                    </svg>
                  </button>
                </div>
              </.form>
            </div>
          <% else %>
            <!-- Session Complete -->
            <div class="p-12 text-center">
              <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-green-100 text-green-600 mb-6">
                <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>

              <h2 class="text-3xl font-bold text-gray-900 mb-4">Session Complete!</h2>
              <p class="text-xl text-gray-600 mb-8">Great job on completing the practice session!</p>

              <div class="flex flex-col sm:flex-row gap-4 justify-center">
                <button
                  phx-click="reset_session"
                  class="inline-flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 transition-colors"
                >
                  Start New Session
                </button>

                <a
                  href="/dashboard"
                  class="inline-flex items-center justify-center px-8 py-3 border border-gray-300 text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 transition-colors"
                >
                  View Results
                </a>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Viral Prompt Modal -->
      <%= if @show_viral_modal and @viral_prompt do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 class="text-xl font-bold text-gray-900 mb-4"><%= @viral_prompt.title %></h3>
            <p class="text-gray-600 mb-6"><%= @viral_prompt.message %></p>

            <div class="flex gap-3">
              <button
                phx-click="viral_prompt_clicked"
                phx-value-prompt_log_id={@viral_prompt.log_id}
                class="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                <%= @viral_prompt.cta_text %>
              </button>

              <button
                phx-click="close_viral_modal"
                class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Maybe Later
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{remaining_seconds}", 2, "0")}"
  end
end
