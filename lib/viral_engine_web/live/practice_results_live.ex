defmodule ViralEngineWeb.PracticeResultsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{PracticeContext, ChallengeContext, RallyContext}
  require Logger

  @impl true
  def mount(%{"id" => session_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    case PracticeContext.get_user_session(session_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Practice session not found")
         |> redirect(to: "/dashboard")}

      session ->
        if session.completed do
          initialize_results(socket, user, session)
        else
          {:ok,
           socket
           |> put_flash(:warning, "Practice session not yet completed")
           |> redirect(to: "/practice?session_id=#{session_id}")}
        end
    end
  end

  defp initialize_results(socket, user, session) do
    # Load session with answers
    answers = PracticeContext.list_session_answers(session.id)
    steps = session.steps

    # Create question-by-question breakdown
    breakdown = create_breakdown(steps, answers)

    # Subscribe to leaderboard updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "leaderboard:#{session.subject}")
    end

    # Get leaderboard data
    leaderboard = get_leaderboard(session.subject, user.id)

    # Get percentile rank
    {:ok, rank_info} = PracticeContext.get_session_rank(session.id)

    share_url = generate_share_url(session.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:session, session)
      |> assign(:breakdown, breakdown)
      |> assign(:leaderboard, leaderboard)
      |> assign(:rank_info, rank_info)
      |> assign(:share_url, share_url)
      |> assign(:show_share_modal, false)
      |> assign(:show_challenge_modal, false)
      |> assign(:show_rally_modal, false)
      |> assign(:challenge_url, nil)
      |> assign(:rally_url, nil)
      |> assign(:creating_challenge, false)
      |> assign(:creating_rally, false)

    {:ok, socket}
  end

  @impl true
  def handle_info({:leaderboard_update, _data}, socket) do
    # Refresh leaderboard when updates arrive
    session = socket.assigns.session
    leaderboard = get_leaderboard(session.subject, socket.assigns.user.id)

    {:noreply, assign(socket, :leaderboard, leaderboard)}
  end

  @impl true
  def handle_event("toggle_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, !socket.assigns.show_share_modal)}
  end

  @impl true
  def handle_event("challenge_friend", _params, socket) do
    session = socket.assigns.session
    user = socket.assigns.user

    socket = assign(socket, :creating_challenge, true)

    # Create buddy challenge with micro-deck
    case ChallengeContext.create_challenge(user.id, session.id, share_method: "copy_link") do
      {:ok, challenge} ->
        challenge_url = ChallengeContext.generate_challenge_url(challenge)

        {:noreply,
         socket
         |> assign(:challenge_url, challenge_url)
         |> assign(:show_challenge_modal, true)
         |> assign(:creating_challenge, false)
         |> put_flash(:success, "Buddy Challenge created! Share to earn Streak Shields.")}

      {:error, reason} ->
        Logger.error("Failed to create challenge: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:creating_challenge, false)
         |> put_flash(:error, "Failed to create challenge. Please try again.")}
    end
  end

  @impl true
  def handle_event("close_challenge_modal", _params, socket) do
    {:noreply, assign(socket, :show_challenge_modal, false)}
  end

  @impl true
  def handle_event("copy_challenge_link", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:success, "Challenge link copied! Share with a friend to earn rewards.")}
  end

  @impl true
  def handle_event("create_rally", _params, socket) do
    session = socket.assigns.session
    user = socket.assigns.user

    socket = assign(socket, :creating_rally, true)

    # Create rally from practice session
    case RallyContext.create_rally(user.id, session.id, source_type: :practice, share_method: "copy_link") do
      {:ok, rally, _attribution_link} ->
        rally_url = RallyContext.generate_rally_link(rally)

        {:noreply,
         socket
         |> assign(:rally_url, rally_url)
         |> assign(:show_rally_modal, true)
         |> assign(:creating_rally, false)
         |> put_flash(:success, "Rally created! Share with friends to compete.")}

      {:error, reason} ->
        Logger.error("Failed to create rally: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:creating_rally, false)
         |> put_flash(:error, "Failed to create rally. Please try again.")}
    end
  end

  @impl true
  def handle_event("close_rally_modal", _params, socket) do
    {:noreply, assign(socket, :show_rally_modal, false)}
  end

  @impl true
  def handle_event("copy_rally_link", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:success, "Rally link copied! Share to invite friends.")}
  end

  @impl true
  def handle_event("retry_session", _params, socket) do
    session = socket.assigns.session

    # Create new session
    {:ok, new_session} =
      PracticeContext.create_session(%{
        user_id: socket.assigns.user.id,
        session_type: session.session_type,
        subject: session.subject,
        total_steps: session.total_steps
      })

    {:noreply, redirect(socket, to: "/practice?session_id=#{new_session.id}")}
  end

  @impl true
  def handle_event("share_native", _params, socket) do
    # Use Web Share API (handled in JavaScript hook)
    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_share_link", _params, socket) do
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  @impl true
  def handle_event("view_question", %{"question_id" => question_id}, socket) do
    # Scroll to specific question in breakdown
    {:noreply, push_event(socket, "scroll_to", %{id: "question-#{question_id}"})}
  end

  # Private functions

  defp create_breakdown(steps, answers) do
    Enum.map(steps, fn step ->
      answer = Enum.find(answers, fn a -> a.practice_step_id == step.id end)

      %{
        step_number: step.step_number,
        title: step.title,
        content: step.content,
        user_answer: answer && answer.user_answer,
        correct_answer: step.correct_answer,
        is_correct: answer && answer.is_correct,
        feedback: answer && answer.feedback,
        time_spent: answer && answer.time_spent_seconds
      }
    end)
  end

  defp get_leaderboard(subject, current_user_id) do
    # Get top 10 scores for this subject (last 7 days)
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    top_sessions =
      PracticeContext.list_completed_sessions_by_subject(subject, 7)
      |> Enum.filter(fn s -> DateTime.compare(s.updated_at, seven_days_ago) == :gt end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(10)

    # Format leaderboard entries
    entries =
      top_sessions
      |> Enum.with_index(1)
      |> Enum.map(fn {session, rank} ->
        # Anonymize names except for current user
        display_name =
          if session.user_id == current_user_id do
            "You"
          else
            "Player #{String.slice(Integer.to_string(session.user_id), -3..-1)}"
          end

        %{
          rank: rank,
          user: display_name,
          score: session.score,
          time: format_time(session.timer_seconds),
          is_current_user: session.user_id == current_user_id
        }
      end)

    %{
      entries: entries,
      user_rank: find_user_rank(entries, current_user_id),
      total_players: length(top_sessions)
    }
  end

  defp find_user_rank(entries, _user_id) do
    entry = Enum.find(entries, fn e -> e.is_current_user end)
    entry && entry.rank
  end

  defp generate_share_url(session_id) do
    "https://veltutor.com/practice/results/#{session_id}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Practice Results</h1>
          <p class="text-muted-foreground"><%= String.capitalize(@session.subject) %> Practice Session</p>
        </div>

        <!-- Score Overview -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-8">
          <div class="text-center mb-6">
            <div class="inline-block">
              <div class="relative w-32 h-32 mx-auto mb-4">
                <svg class="w-32 h-32 transform -rotate-90" viewBox="0 0 36 36" aria-labelledby="score-title score-desc">
                  <title id="score-title">Overall Score</title>
                  <desc id="score-desc"><%= round(@session.score || 0) %>%</desc>
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
                    stroke-dasharray={"#{@session.score || 0}, 100"}
                    class={"transition-all duration-1000 #{if((@session.score || 0) >= 80, do: "text-green-500", else: if((@session.score || 0) >= 60, do: "text-yellow-500", else: "text-red-500"))}"}
                  />
                </svg>
                <div class="absolute inset-0 flex items-center justify-center">
                  <span class="text-3xl font-bold text-foreground"><%= round(@session.score || 0) %>%</span>
                </div>
              </div>
              <p class="text-sm text-muted-foreground font-medium">Overall Score</p>
            </div>
          </div>

          <!-- Stats Grid -->
          <div class="grid md:grid-cols-5 gap-4">
            <div class="text-center">
              <div class="text-2xl font-bold text-foreground"><%= @session.total_steps %></div>
              <div class="text-sm text-muted-foreground">Questions</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-foreground"><%= Enum.count(@breakdown, & &1.is_correct) %></div>
              <div class="text-sm text-muted-foreground">Correct</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-foreground"><%= format_time(@session.timer_seconds) %></div>
              <div class="text-sm text-muted-foreground">Time</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-foreground"><%= @rank_info.rank || "N/A" %></div>
              <div class="text-sm text-muted-foreground">Rank</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-primary"><%= round(@rank_info.percentile || 0) %>%</div>
              <div class="text-sm text-muted-foreground">Percentile</div>
            </div>
          </div>
        </div>

        <!-- Question Breakdown -->
        <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
          <h2 class="text-xl font-semibold text-foreground mb-4">Question Breakdown</h2>
          <div class="space-y-4">
            <%= for question <- @breakdown do %>
              <div id={"question-#{question.step_number}"} class="border rounded-lg p-4">
                <div class="flex items-start justify-between mb-2">
                  <div class="flex-1">
                    <h3 class="font-medium text-foreground mb-1">Question <%= question.step_number %></h3>
                    <p class="text-sm text-muted-foreground mb-2"><%= question.title %></p>
                    <div class="text-sm">
                      <span class="font-medium">Your answer:</span>
                      <span class={"ml-2 #{if(question.is_correct, do: "text-green-600", else: "text-red-600")}"}>
                        <%= question.user_answer || "Not answered" %>
                      </span>
                    </div>
                    <%= if not question.is_correct and question.correct_answer do %>
                      <div class="text-sm mt-1">
                        <span class="font-medium">Correct answer:</span>
                        <span class="ml-2 text-green-600"><%= question.correct_answer %></span>
                      </div>
                    <% end %>
                  </div>
                  <div class="flex-shrink-0 ml-4">
                    <%= if question.is_correct do %>
                      <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                        <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                        </svg>
                      </div>
                    <% else %>
                      <div class="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center">
                        <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </div>
                    <% end %>
                  </div>
                </div>
                <%= if question.feedback do %>
                  <div class="mt-3 p-3 bg-muted rounded-lg">
                    <p class="text-sm text-foreground"><%= question.feedback %></p>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Leaderboard -->
        <%= if length(@leaderboard.entries) > 0 do %>
          <div class="bg-card text-card-foreground rounded-lg border p-6 mb-8">
            <h2 class="text-xl font-semibold text-foreground mb-4">Leaderboard</h2>
            <div class="space-y-2">
              <%= for entry <- @leaderboard.entries do %>
                <div class={"flex items-center justify-between p-3 rounded-lg #{if(entry.is_current_user, do: "bg-primary/10 border border-primary/20", else: "bg-muted/50")}"}>
                  <div class="flex items-center space-x-3">
                    <span class="flex-shrink-0 w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-sm font-bold text-secondary-foreground">
                      <%= entry.rank %>
                    </span>
                    <span class={"font-medium #{if(entry.is_current_user, do: "text-primary", else: "text-foreground")}"}>
                      <%= entry.user %>
                    </span>
                  </div>
                  <div class="text-right">
                    <div class="font-bold text-foreground"><%= entry.score %>%</div>
                    <div class="text-sm text-muted-foreground"><%= entry.time %></div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Action Buttons -->
        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <button
            phx-click="retry_session"
            class="flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors"
            aria-label="Retry this practice session"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <span>Retry Session</span>
          </button>

          <button
            phx-click="challenge_friend"
            class="flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-semibold px-6 py-3 rounded-md transition-colors"
            aria-label="Challenge a friend to beat your score"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <span>Challenge Friend</span>
          </button>

          <button
            phx-click="create_rally"
            class="flex items-center justify-center space-x-2 bg-gradient-to-br from-blue-500 to-indigo-600 text-white hover:from-blue-600 hover:to-indigo-700 font-semibold px-6 py-3 rounded-md transition-all shadow-sm hover:shadow-md"
            aria-label="Create a leaderboard rally"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
            </svg>
            <span>Create Rally</span>
          </button>

          <button
            phx-click="toggle_share_modal"
            class="flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-semibold px-6 py-3 rounded-md transition-colors"
            aria-label="Share your results"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
            </svg>
            <span>Share Results</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Buddy Challenge Modal -->
    <%= if @show_challenge_modal && @challenge_url do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_challenge_modal" role="dialog" aria-modal="true" aria-labelledby="challenge-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6 animate-slide-up" phx-click="stop-propagation">
          <!-- Icon Header -->
          <div class="flex justify-center mb-4">
            <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-indigo-600 rounded-full flex items-center justify-center">
              <svg class="w-9 h-9 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
          </div>

          <h3 id="challenge-modal-title" class="text-xl font-bold text-foreground mb-2 text-center">Buddy Challenge Created!</h3>
          <p class="text-muted-foreground mb-4 text-center text-sm">
            I just scored <span class="font-semibold text-foreground"><%= round(@session.score || 0) %>%</span> on <%= String.capitalize(@session.subject) %>! Think you can beat me?
          </p>

          <!-- Reward Info -->
          <div class="bg-gradient-to-br from-amber-50 to-orange-50 border-2 border-amber-200 rounded-lg p-4 mb-4">
            <div class="flex items-start space-x-3">
              <svg class="w-6 h-6 text-amber-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
              <div class="flex-1">
                <p class="text-sm font-semibold text-amber-900">Earn Streak Shields!</p>
                <p class="text-xs text-amber-800">Both you and your friend get a Streak Shield when they complete this 5-question challenge.</p>
              </div>
            </div>
          </div>

          <!-- Challenge Link -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-foreground mb-2">Challenge Link:</label>
            <div class="flex space-x-2">
              <input
                type="text"
                value={@challenge_url}
                readonly
                data-clipboard-text={@challenge_url}
                class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm font-mono"
                aria-label="Challenge URL"
              />
              <button
                phx-click="copy_challenge_link"
                data-clipboard-text={@challenge_url}
                class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md transition-colors flex-shrink-0"
                aria-label="Copy challenge link"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Share Buttons -->
          <div class="grid grid-cols-2 gap-2 mb-4">
            <a
              href={"https://wa.me/?text=Think you can beat my score? Try this challenge! #{URI.encode(@challenge_url)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center justify-center space-x-2 bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/>
              </svg>
              <span>WhatsApp</span>
            </a>
            <button
              phx-click="copy_challenge_link"
              data-clipboard-text={@challenge_url}
              class="flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>
          </div>

          <button
            phx-click="close_challenge_modal"
            class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
            aria-label="Close challenge modal"
          >
            Close
          </button>
        </div>
      </div>
    <% end %>

    <!-- Share Modal -->
    <%= if @show_share_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="toggle_share_modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="share-modal-title" class="text-xl font-bold text-foreground mb-4">Share Your Results</h3>
          <p class="text-muted-foreground mb-6">Show off your practice session results!</p>

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
              phx-click="share_native"
              class="w-full flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-medium px-4 py-2 rounded-md transition-colors"
              aria-label="Share using device share options"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
              </svg>
              <span>Share</span>
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

    <!-- Rally Creation Modal -->
    <%= if @show_rally_modal && @rally_url do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_rally_modal" role="dialog" aria-modal="true" aria-labelledby="rally-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6 animate-slide-up" phx-click="stop-propagation">
          <!-- Icon Header -->
          <div class="flex justify-center mb-4">
            <div class="w-16 h-16 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full flex items-center justify-center">
              <svg class="w-9 h-9 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
              </svg>
            </div>
          </div>

          <h3 id="rally-modal-title" class="text-xl font-bold text-foreground mb-2 text-center">Rally Created!</h3>
          <p class="text-muted-foreground mb-4 text-center text-sm">
            You scored <span class="font-semibold text-foreground"><%= round(@session.score || 0) %>%</span> in the Top <span class="font-semibold text-primary"><%= round(@rank_info.percentile || 0) %>%</span>!
            <br />
            Invite friends to join this <%= String.capitalize(@session.subject) %> leaderboard challenge.
          </p>

          <!-- Rally Info -->
          <div class="bg-gradient-to-br from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-lg p-4 mb-4">
            <div class="flex items-start space-x-3">
              <svg class="w-6 h-6 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
              <div class="flex-1">
                <p class="text-sm font-semibold text-blue-900">Real-Time Leaderboard</p>
                <p class="text-xs text-blue-800">Track rankings live as friends join and compete. Rally lasts 7 days!</p>
              </div>
            </div>
          </div>

          <!-- Rally Link -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-foreground mb-2">Rally Link:</label>
            <div class="flex space-x-2">
              <input
                type="text"
                value={@rally_url}
                readonly
                data-clipboard-text={@rally_url}
                class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm font-mono"
                aria-label="Rally URL"
              />
              <button
                phx-click="copy_rally_link"
                data-clipboard-text={@rally_url}
                class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md transition-colors flex-shrink-0"
                aria-label="Copy rally link"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Share Buttons -->
          <div class="grid grid-cols-2 gap-2 mb-4">
            <a
              href={"https://wa.me/?text=I scored #{round(@session.score || 0)}%25 in #{String.capitalize(@session.subject)}! Join my leaderboard rally and see if you can beat me: #{URI.encode(@rally_url)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center justify-center space-x-2 bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/>
              </svg>
              <span>WhatsApp</span>
            </a>
            <button
              phx-click="copy_rally_link"
              data-clipboard-text={@rally_url}
              class="flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>
          </div>

          <button
            phx-click="close_rally_modal"
            class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
            aria-label="Close rally modal"
          >
            Close
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  # Private functions

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end
end
