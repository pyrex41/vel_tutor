defmodule ViralEngineWeb.DiagnosticResultsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{DiagnosticContext, RallyContext, ViralPrompts, BadgeContext, XPContext}
  require Logger

  on_mount(ViralEngineWeb.Live.ViralPromptsHook)

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
        if assessment.completed do
          initialize_results(socket, user, assessment)
        else
          {:ok,
           socket
           |> put_flash(:warning, "Assessment not yet completed")
           |> redirect(to: "/diagnostic/#{assessment_id}")}
        end
    end
  end

  defp initialize_results(socket, user, assessment) do
    results = assessment.results
    recommendations = generate_ai_recommendations(assessment)
    share_url = generate_share_url(assessment.id)

    # Grant XP for completing assessment (async)
    Task.start(fn ->
      # Base XP for completing assessment
      base_xp = 100
      # 2 XP per score point
      score_bonus = round((assessment.score || 0) * 2)
      XPContext.grant_xp(user.id, base_xp + score_bonus, :diagnostic_assessment)
    end)

    # Check for badge unlocks (async)
    Task.start(fn ->
      BadgeContext.check_and_unlock_badges(user.id, :assessment_completed)
    end)

    # Trigger viral prompt for results rally
    viral_prompt = trigger_results_rally_prompt(user.id, assessment)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:assessment, assessment)
      |> assign(:results, results)
      |> assign(:recommendations, recommendations)
      |> assign(:share_url, share_url)
      |> assign(:show_share_modal, false)
      |> assign(:viral_prompt, viral_prompt)
      |> assign(:show_viral_modal, viral_prompt != nil)
      |> assign(:rally_created, false)
      |> assign(:rally_link, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, !socket.assigns.show_share_modal)}
  end

  @impl true
  def handle_event("challenge_friend", _params, socket) do
    assessment = socket.assigns.assessment

    # Generate challenge link
    challenge_url = "#{socket.assigns.share_url}?challenge=#{assessment.id}"

    {:noreply,
     socket
     |> assign(:share_url, challenge_url)
     |> assign(:show_share_modal, true)
     |> put_flash(:info, "Challenge link generated! Share with a friend.")}
  end

  @impl true
  def handle_event("study_together", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Study together feature coming soon!")
     |> redirect(to: "/dashboard")}
  end

  @impl true
  def handle_event("retake_assessment", _params, socket) do
    assessment = socket.assigns.assessment

    # Create new assessment with same parameters
    {:ok, new_assessment} =
      DiagnosticContext.create_assessment(%{
        user_id: socket.assigns.user.id,
        subject: assessment.subject,
        grade_level: assessment.grade_level
      })

    {:noreply, redirect(socket, to: "/diagnostic/#{new_assessment.id}")}
  end

  @impl true
  def handle_event("share_native", _params, socket) do
    # Use Web Share API (handled in JavaScript hook)
    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_share_link", _params, socket) do
    # Copy to clipboard (handled in JavaScript)
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  @impl true
  def handle_event("create_rally", _params, socket) do
    assessment = socket.assigns.assessment
    user = socket.assigns.user

    case RallyContext.create_rally(user.id, assessment.id) do
      {:ok, rally} ->
        rally_link = RallyContext.generate_rally_link(rally)

        {:noreply,
         socket
         |> assign(:rally_created, true)
         |> assign(:rally_link, rally_link)
         |> assign(:show_viral_modal, false)
         |> put_flash(:success, "Rally created! Share the link to invite friends.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not create rally. Please try again.")}
    end
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

    # Close modal
    {:noreply, assign(socket, :show_viral_modal, false)}
  end

  # Private functions

  defp generate_ai_recommendations(assessment) do
    results = assessment.results
    skill_heatmap = results["skill_heatmap"] || %{}

    # Find weak skills (< 70%)
    weak_skills =
      skill_heatmap
      |> Enum.filter(fn {_skill, score} -> score < 70 end)
      |> Enum.sort_by(fn {_skill, score} -> score end)
      |> Enum.take(3)

    # Find strong skills (>= 80%)
    strong_skills =
      skill_heatmap
      |> Enum.filter(fn {_skill, score} -> score >= 80 end)
      |> Enum.sort_by(fn {_skill, score} -> -score end)
      |> Enum.take(3)

    recommendations = []

    # Add recommendations for weak skills
    recommendations =
      if length(weak_skills) > 0 do
        weak_skill_names = Enum.map(weak_skills, fn {skill, _} -> skill end) |> Enum.join(", ")

        [
          "Focus on #{weak_skill_names} - these areas need more practice",
          "Try daily 10-minute drills to improve #{Enum.at(weak_skills, 0) |> elem(0)}",
          "Watch tutorial videos on #{weak_skill_names} concepts"
          | recommendations
        ]
      else
        recommendations
      end

    # Add recommendations for strong skills
    recommendations =
      if length(strong_skills) > 0 do
        strong_skill_names =
          Enum.map(strong_skills, fn {skill, _} -> skill end) |> Enum.join(", ")

        [
          "Great job on #{strong_skill_names}! Keep up the excellent work",
          "Challenge yourself with advanced #{Enum.at(strong_skills, 0) |> elem(0)} problems"
          | recommendations
        ]
      else
        recommendations
      end

    # Add general recommendations
    accuracy = results["accuracy"] || 0

    recommendations =
      cond do
        accuracy >= 90 ->
          [
            "You're performing excellently! Consider taking advanced practice tests"
            | recommendations
          ]

        accuracy >= 70 ->
          ["Solid performance! Keep practicing to reach expert level" | recommendations]

        accuracy >= 50 ->
          ["Good start! Focus on fundamentals and practice regularly" | recommendations]

        true ->
          [
            "Don't worry! Everyone starts somewhere. Practice daily and you'll improve"
            | recommendations
          ]
      end

    recommendations
  end

  defp generate_share_url(assessment_id) do
    # In production, this would generate a proper shareable URL
    "https://veltutor.com/diagnostic/results/#{assessment_id}"
  end

  defp trigger_results_rally_prompt(user_id, assessment) do
    event_data = %{
      assessment_id: assessment.id,
      score: assessment.results["overall_score"] || 0,
      subject: assessment.subject,
      grade_level: assessment.grade_level
    }

    case ViralPrompts.trigger_prompt(:diagnostic_completed, user_id, event_data) do
      {:ok, prompt} ->
        # Broadcast event for analytics
        ViralPrompts.broadcast_event(:diagnostic_completed, user_id, event_data)
        prompt

      {:throttled, reason} ->
        Logger.info("Viral prompt throttled for user #{user_id}: #{reason}")
        nil

      {:no_prompt, reason} ->
        Logger.info("No viral prompt for user #{user_id}: #{reason}")
        # Fallback to default prompt
        ViralPrompts.get_default_prompt(:diagnostic_completed)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-5xl mx-auto">
        <!-- Hero Section -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-6 text-center">
          <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
            <svg class="h-12 w-12 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
            </svg>
          </div>
          <h1 class="text-4xl font-bold text-foreground mb-2">Assessment Complete!</h1>
          <p class="text-muted-foreground text-lg mb-6"><%= String.capitalize(@assessment.subject) %> · Grade <%= @assessment.grade_level %></p>

          <div class="inline-block">
            <div class="relative w-32 h-32 mx-auto mb-4">
              <svg class="w-32 h-32 transform -rotate-90" viewBox="0 0 36 36" aria-labelledby="score-title score-desc">
                <title id="score-title">Overall Score</title>
                <desc id="score-desc"><%= round(@assessment.score || 0) %>%</desc>
                <path
                  d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-dasharray="100, 100"
                  class="text-muted"
                />
                  <path
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-dasharray={"#{@assessment.score || 0}, 100"}
                    class={"transition-all duration-1000 #{if((@assessment.score || 0) >= 75, do: "text-green-500", else: if((@assessment.score || 0) >= 50, do: "text-yellow-500", else: "text-red-500"))}"}
                  />
              </svg>
              <div class="absolute inset-0 flex items-center justify-center">
                <span class="text-3xl font-bold text-foreground"><%= round(@assessment.score || 0) %>%</span>
              </div>
            </div>
            <p class="text-sm text-muted-foreground font-medium">Overall Score</p>
          </div>
        </div>

        <!-- Stats Cards -->
        <div class="grid md:grid-cols-4 gap-4 mb-6">
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-muted-foreground">Accuracy</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <p class="text-3xl font-bold text-foreground"><%= round((@results["accuracy"] || 0) * 100) %>%</p>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-muted-foreground">Questions</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <p class="text-3xl font-bold text-foreground"><%= @assessment.total_questions %></p>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-muted-foreground">Correct</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <p class="text-3xl font-bold text-foreground"><%= @results["correct_answers"] || 0 %></p>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-muted-foreground">Time Spent</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <p class="text-3xl font-bold text-foreground"><%= div(@results["time_spent_seconds"] || 0, 60) %><span class="text-lg text-muted-foreground">m</span></p>
          </div>
        </div>

        <!-- Skill Heatmap -->
        <%= if @results["skill_heatmap"] && map_size(@results["skill_heatmap"]) > 0 do %>
          <div class="bg-card text-card-foreground rounded-lg border p-6 mb-6">
            <h2 class="text-xl font-bold text-foreground mb-4 flex items-center">
              <svg class="w-6 h-6 mr-2 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
              Skill Breakdown
            </h2>
            <div class="space-y-4">
              <%= for {skill, score} <- Enum.sort_by(@results["skill_heatmap"], fn {_, s} -> -s end) do %>
                <div>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-foreground capitalize"><%= skill %></span>
                     <span class={"text-sm font-bold #{if(score >= 80, do: "text-green-600", else: if(score >= 60, do: "text-yellow-600", else: "text-red-600"))}"}>
                       <%= round(score) %>%
                     </span>
                  </div>
                  <div class="w-full bg-secondary rounded-full h-3 overflow-hidden">
                     <div
                       class={"h-3 rounded-full transition-all duration-500 #{if(score >= 80, do: "bg-green-500", else: if(score >= 60, do: "bg-yellow-500", else: "bg-red-500"))}"}
                       style={"width: #{score}%"}
                     >
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
         <% end %>

         <!-- Performance Chart -->
         <%= if @results["skill_heatmap"] && map_size(@results["skill_heatmap"]) > 0 do %>
           <div class="bg-card text-card-foreground rounded-lg border p-6 mb-6">
             <h2 class="text-xl font-bold text-foreground mb-4 flex items-center">
               <svg class="w-6 h-6 mr-2 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V8a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 0012.586 3H8a2 2 0 00-2 2v2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
               </svg>
               Performance Overview
             </h2>
              <div class="h-64 md:h-80">
                <svg viewBox="0 0 400 200" class="w-full h-full" role="img" aria-labelledby="chart-title chart-desc">
                 <title id="chart-title">Skill Performance Chart</title>
                 <desc id="chart-desc">Bar chart showing performance scores across different skills</desc>
                 <%= for {{skill, score}, index} <- Enum.with_index(Enum.sort_by(@results["skill_heatmap"], fn {_, s} -> -s end)) do %>
                   <% x_pos = 20 + index * 60 %>
                   <% bar_height = score * 1.6 %>
                    <rect
                      x={"#{x_pos}"}
                      y={"#{180 - bar_height}"}
                      width="40"
                      height={"#{bar_height}"}
                      class={"fill-current #{if(score >= 80, do: "text-green-500", else: if(score >= 60, do: "text-yellow-500", else: "text-red-500"))}"}
                      aria-label={"#{skill}: #{round(score)}%"}
                    />
                    <text x={"#{x_pos + 20}"} y="195" text-anchor="middle" class="fill-current text-muted-foreground text-xs" aria-hidden="true">
                      <%= String.slice(skill, 0, 6) %>
                    </text>
                 <% end %>
                 <!-- Y-axis labels -->
                 <text x="5" y="20" class="fill-current text-muted-foreground text-xs" aria-hidden="true">100%</text>
                 <text x="5" y="100" class="fill-current text-muted-foreground text-xs" aria-hidden="true">50%</text>
                 <text x="5" y="180" class="fill-current text-muted-foreground text-xs" aria-hidden="true">0%</text>
               </svg>
             </div>
           </div>
         <% end %>

         <!-- AI Recommendations -->
        <%= if length(@recommendations) > 0 do %>
          <div class="bg-card text-card-foreground rounded-lg border p-6 mb-6">
            <h2 class="text-xl font-bold text-foreground mb-4 flex items-center">
              <svg class="w-6 h-6 mr-2 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              Personalized Recommendations
            </h2>
            <div class="space-y-3">
              <%= for {recommendation, index} <- Enum.with_index(@recommendations) do %>
                <div class="flex items-start space-x-3 p-3 bg-muted rounded-lg border">
                  <span class="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-primary text-primary-foreground text-sm font-bold">
                    <%= index + 1 %>
                  </span>
                  <p class="text-foreground leading-relaxed"><%= recommendation %></p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Action Buttons -->
        <div class="bg-card text-card-foreground rounded-lg border p-6 mb-6">
          <h2 class="text-xl font-bold text-foreground mb-4">What's Next?</h2>
          <div class="grid md:grid-cols-2 gap-4">
            <button
              phx-click="retake_assessment"
              class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
              aria-label="Retake the diagnostic assessment"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span>Retake Assessment</span>
            </button>

            <button
              phx-click="challenge_friend"
              class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
              aria-label="Challenge a friend to take the assessment"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span>Challenge a Friend</span>
            </button>

            <button
              phx-click="create_rally"
              class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
              aria-label="Create a study rally"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z" />
              </svg>
              <span>Create Rally</span>
            </button>

            <button
              phx-click="study_together"
              class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-4 rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
              aria-label="Start a study session together"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
              <span>Study Together</span>
            </button>
          </div>

          <%= if @rally_created && @rally_link do %>
            <div class="mt-6 p-4 bg-muted rounded-lg border">
              <div class="flex items-start space-x-3">
                <svg class="w-6 h-6 text-primary flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
                <div class="flex-1">
                  <p class="text-foreground font-semibold mb-2">Rally Created!</p>
                  <p class="text-sm text-muted-foreground mb-2">Share this link to invite friends:</p>
                  <div class="flex items-center space-x-2">
                    <input
                      type="text"
                      value={@rally_link}
                      readonly
                      class="flex-1 px-3 py-2 bg-background border border-input rounded-lg text-sm"
                      aria-label="Rally share link"
                    />
                    <button
                      phx-click="copy_share_link"
                      class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-lg text-sm font-medium"
                      aria-label="Copy rally link"
                    >
                      Copy
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Share Button -->
        <div class="text-center">
          <button
            phx-click="toggle_share_modal"
            class="inline-flex items-center space-x-2 text-primary hover:text-primary/80 font-medium transition-colors"
            aria-label="Share your assessment results"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
            </svg>
            <span>Share Results</span>
          </button>
        </div>
      </div>
    </div>

     <!-- Share Modal -->
     <%= if @show_share_modal do %>
       <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="toggle_share_modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
         <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
           <h3 id="share-modal-title" class="text-xl font-bold text-foreground mb-4">Share Your Results</h3>
           <p class="text-muted-foreground mb-6">Let your friends know about your achievement!</p>

           <div class="mb-6">
             <input
               type="text"
               value={@share_url}
               readonly
               class="w-full px-3 py-2 bg-background border border-input rounded-md text-sm"
               aria-label="Share URL"
             />
           </div>

           <div class="space-y-3">
             <button
               phx-click="copy_share_link"
               class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
               aria-label="Copy share link to clipboard"
             >
               <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
               </svg>
               <span>Copy Link</span>
             </button>

             <button
               phx-click="toggle_share_modal"
               class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
               aria-label="Close share modal"
             >
               Close
             </button>
           </div>
         </div>
       </div>
     <% end %>

    <!-- Viral Prompt Modal -->
    <%= if @show_viral_modal && @viral_prompt do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" phx-click="close_viral_modal">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 transform transition-all" phx-click="viral_prompt_clicked" phx-value-prompt_log_id={@viral_prompt.log_id}>
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-purple-100 mb-4">
              <svg class="h-10 w-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <h3 class="text-2xl font-bold text-gray-900 mb-4"><%= @viral_prompt.message %></h3>
            <p class="text-gray-600 mb-6"><%= @viral_prompt.cta_text %></p>
            <button class="w-full bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-semibold px-6 py-3 rounded-lg shadow-md hover:shadow-lg transition-all duration-200">
              <%= @viral_prompt.cta_text %>
            </button>
            <button phx-click="close_viral_modal" class="mt-4 text-gray-500 hover:text-gray-700 text-sm font-medium">
              Maybe later
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
