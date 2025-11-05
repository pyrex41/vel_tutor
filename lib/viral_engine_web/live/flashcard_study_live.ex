defmodule ViralEngineWeb.FlashcardStudyLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ViralPrompts, StreakContext, FlashcardContext}
  # alias ViralEngine.AchievementContext  # Unused - commented for future use
  require Logger

  on_mount(ViralEngineWeb.Live.ViralPromptsHook)

  @impl true
  def mount(%{"deck_id" => deck_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    case FlashcardContext.get_user_deck(deck_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Deck not found")
         |> redirect(to: "/dashboard")}

      deck ->
        # Get cards due for review
        due_cards = FlashcardContext.get_due_cards(user.id, deck.id)

        if Enum.empty?(due_cards) do
          {:ok,
           socket
           |> put_flash(:info, "No cards due for review! Great job!")
           |> redirect(to: "/flashcards")}
        else
          initialize_study_session(socket, user, deck, due_cards)
        end
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Show deck selection
    decks = FlashcardContext.list_user_decks(user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:stage, :deck_selection)
      |> assign(:decks, decks)
      |> assign(:show_ai_generator, false)

    {:ok, socket}
  end

  defp initialize_study_session(socket, user, deck, due_cards) do
    # Create study session
    {:ok, session} =
      FlashcardContext.create_study_session(%{
        user_id: user.id,
        flashcard_deck_id: deck.id
      })

    # Start timer
    if connected?(socket) do
      Process.send_after(self(), :tick, 1000)
    end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:stage, :studying)
      |> assign(:deck, deck)
      |> assign(:session, session)
      |> assign(:cards, due_cards)
      |> assign(:current_card_index, 0)
      |> assign(:current_card, Enum.at(due_cards, 0))
      |> assign(:show_back, false)
      |> assign(:session_duration, 0)
      |> assign(:cards_reviewed, 0)
      |> assign(:cards_mastered, 0)

    {:ok, socket}
  end

  # Timer tick
  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.stage == :studying do
      new_duration = socket.assigns.session_duration + 1
      Process.send_after(self(), :tick, 1000)
      {:noreply, assign(socket, :session_duration, new_duration)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_deck", %{"deck_id" => deck_id}, socket) do
    {:noreply, redirect(socket, to: "/flashcards/study/#{deck_id}")}
  end

  @impl true
  def handle_event("show_ai_generator", _params, socket) do
    {:noreply, assign(socket, :show_ai_generator, true)}
  end

  @impl true
  def handle_event(
        "generate_ai_deck",
        %{"subject" => subject, "topic" => topic, "difficulty" => difficulty},
        socket
      ) do
    diff = String.to_integer(difficulty)

    # Generate AI deck (always succeeds in current implementation)
    {:ok, %{deck: deck}} =
      FlashcardContext.generate_ai_deck(socket.assigns.user.id, subject, topic, diff, 10)

    {:noreply,
     socket
     |> put_flash(:success, "AI deck generated! #{deck.title}")
     |> redirect(to: "/flashcards/study/#{deck.id}")}
  end

  @impl true
  def handle_event("flip_card", _params, socket) do
    {:noreply, assign(socket, :show_back, !socket.assigns.show_back)}
  end

  @impl true
  def handle_event("rate_card", %{"rating" => rating_str}, socket) do
    rating = String.to_integer(rating_str)
    current_card = socket.assigns.current_card
    session = socket.assigns.session

    # Record review
    {:ok, review} =
      FlashcardContext.record_review(%{
        user_id: socket.assigns.user.id,
        flashcard_id: current_card.id,
        flashcard_study_session_id: session.id,
        rating: rating,
        response_time_seconds: socket.assigns.session_duration
      })

    # Update session stats
    cards_reviewed = socket.assigns.cards_reviewed + 1

    cards_mastered =
      if review.is_mastered,
        do: socket.assigns.cards_mastered + 1,
        else: socket.assigns.cards_mastered

    # Update database session
    FlashcardContext.update_study_session(session, %{
      cards_reviewed: cards_reviewed,
      cards_mastered: cards_mastered,
      session_duration_seconds: socket.assigns.session_duration
    })

    # Move to next card
    next_index = socket.assigns.current_card_index + 1

    if next_index >= length(socket.assigns.cards) do
      # Session complete
      complete_session(socket)
    else
      # Next card
      next_card = Enum.at(socket.assigns.cards, next_index)

      {:noreply,
       socket
       |> assign(:current_card_index, next_index)
       |> assign(:current_card, next_card)
       |> assign(:show_back, false)
       |> assign(:cards_reviewed, cards_reviewed)
       |> assign(:cards_mastered, cards_mastered)}
    end
  end

  @impl true
  def handle_event("swipe_card", %{"direction" => direction, "rating" => rating_str}, socket) do
    # Handle swipe gesture (triggered by Alpine.js)
    # "left" = again (rating 1), "right" = good (rating 3), "up" = easy (rating 5)
    rating =
      case direction do
        "left" -> 1
        "right" -> 3
        "up" -> 5
        _ -> String.to_integer(rating_str)
      end

    handle_event("rate_card", %{"rating" => Integer.to_string(rating)}, socket)
  end

  @impl true
  def handle_event("end_session", _params, socket) do
    complete_session(socket)
  end

  defp complete_session(socket) do
    session = socket.assigns.session
    user_id = socket.assigns.user.id

    # Complete session and calculate score
    {:ok, completed_session} = FlashcardContext.complete_study_session(session.id)

    # Record activity for streak tracking
    StreakContext.record_activity(user_id)

    # Check for achievements
    trigger_achievements(user_id, completed_session)

    # Trigger viral prompt
    viral_prompt = trigger_completion_prompt(user_id, completed_session)

    {:noreply,
     socket
     |> assign(:stage, :completed)
     |> assign(:session, completed_session)
     |> assign(:viral_prompt, viral_prompt)
     |> assign(:show_viral_modal, viral_prompt != nil)
     |> assign(:user_id, user_id)
     |> put_flash(:success, "Study session completed! Score: #{completed_session.score}%")}
  end

  defp trigger_achievements(user_id, session) do
    # Trigger achievements based on performance
    # This is a simplified version - in production would integrate with full achievement system

    Task.start(fn ->
      cond do
        session.score == 100 ->
          Logger.info("Achievement unlocked: Perfect Session for user #{user_id}")

        # AchievementContext.unlock_achievement(user_id, "perfect_flashcard_session")

        session.score >= 80 ->
          Logger.info("Achievement progress: High Scorer for user #{user_id}")

        # AchievementContext.increment_achievement(user_id, "high_scorer", 1)

        session.cards_reviewed >= 50 ->
          Logger.info("Achievement unlocked: Flashcard Master for user #{user_id}")

        # AchievementContext.unlock_achievement(user_id, "flashcard_master_50")

        true ->
          :ok
      end
    end)
  end

  # Helper functions

  defp trigger_completion_prompt(user_id, session) do
    event_data = %{
      session_id: session.id,
      score: session.score || 0,
      cards_reviewed: session.cards_reviewed,
      cards_mastered: session.cards_mastered,
      duration: session.session_duration_seconds
    }

    case ViralPrompts.trigger_prompt(:flashcard_session_completed, user_id, event_data) do
      {:ok, prompt} ->
        # Broadcast event for analytics
        ViralPrompts.broadcast_event(:flashcard_session_completed, user_id, event_data)
        prompt

      {:throttled, reason} ->
        Logger.info("Viral prompt throttled for user #{user_id}: #{reason}")
        nil

      {:no_prompt, reason} ->
        Logger.info("No viral prompt for user #{user_id}: #{reason}")
        # Fallback to default prompt
        ViralPrompts.get_default_prompt(:flashcard_session_completed)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <%= case @stage do %>
        <% :deck_selection -> %>
          <!-- Deck Selection Stage -->
          <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <h1 class="text-3xl font-bold text-gray-900 mb-8">Choose a Deck to Study</h1>

            <!-- AI Generator -->
            <%= if @show_ai_generator do %>
              <div class="bg-white border border-gray-200 rounded-lg p-6 mb-8">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">AI Flashcard Generator</h3>

                <.form :let={f} for={%{}} as={:generator} phx-submit="generate_ai_deck" class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Subject</label>
                    <input
                      type="text"
                      name="subject"
                      placeholder="e.g., Math, Science, History"
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Topic</label>
                    <input
                      type="text"
                      name="topic"
                      placeholder="e.g., Algebra, Cells, World War II"
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Difficulty</label>
                    <select
                      name="difficulty"
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    >
                      <option value="1">Beginner</option>
                      <option value="2">Intermediate</option>
                      <option value="3" selected>Advanced</option>
                    </select>
                  </div>

                  <button
                    type="submit"
                    class="w-full px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
                  >
                    Generate AI Deck
                  </button>
                </.form>
              </div>
            <% else %>
              <button
                phx-click="show_ai_generator"
                class="w-full mb-8 px-6 py-4 bg-gradient-to-r from-purple-500 to-blue-600 text-white rounded-lg hover:from-purple-600 hover:to-blue-700 transition-colors font-medium flex items-center justify-center gap-2"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"/>
                </svg>
                Generate AI Flashcards
              </button>
            <% end %>

            <!-- Deck List -->
            <div class="grid sm:grid-cols-2 gap-6">
              <%= for deck <- @decks do %>
                <button
                  phx-click="select_deck"
                  phx-value-deck_id={deck.id}
                  class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg hover:border-blue-500 transition-all text-left"
                >
                  <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= deck.title %></h3>
                  <p class="text-sm text-gray-600 mb-4"><%= deck.description %></p>

                  <div class="flex items-center gap-4 text-sm">
                    <span class="text-gray-700"><%= deck.card_count %> cards</span>
                    <span class="text-blue-600"><%= deck.due_count %> due</span>
                  </div>
                </button>
              <% end %>
            </div>

            <%= if length(@decks) == 0 do %>
              <div class="text-center py-16">
                <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gray-100 text-gray-400 mb-4">
                  <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"/>
                    <path fill-rule="evenodd" d="M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z" clip-rule="evenodd"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">No Decks Yet</h3>
                <p class="text-gray-600">Create your first deck using the AI generator!</p>
              </div>
            <% end %>
          </div>

        <% :studying -> %>
          <!-- Study Session Stage -->
          <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <!-- Header -->
            <div class="flex items-center justify-between mb-8">
              <div>
                <h1 class="text-2xl font-bold text-gray-900"><%= @deck.title %></h1>
                <p class="text-sm text-gray-600">
                  Card <%= @current_card_index + 1 %> of <%= length(@cards) %>
                </p>
              </div>

              <button
                phx-click="end_session"
                class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
              >
                End Session
              </button>
            </div>

            <!-- Progress Bar -->
            <div class="w-full bg-gray-200 rounded-full h-2 mb-8">
              <div
                class="h-2 bg-blue-600 rounded-full transition-all duration-300"
                style={"width: #{(@current_card_index / length(@cards)) * 100}%"}
              >
              </div>
            </div>

            <!-- Flashcard -->
            <div class="mb-8">
              <div class="bg-white border-2 border-gray-200 rounded-xl shadow-lg p-12 min-h-[400px] flex items-center justify-center">
                <%= if @show_back do %>
                  <!-- Back of Card -->
                  <div class="text-center w-full">
                    <div class="text-sm text-gray-500 mb-4">Answer</div>
                    <div class="text-xl text-gray-900 leading-relaxed">
                      <%= @current_card.back_content %>
                    </div>
                  </div>
                <% else %>
                  <!-- Front of Card -->
                  <div class="text-center w-full">
                    <div class="text-sm text-gray-500 mb-4">Question</div>
                    <div class="text-2xl font-semibold text-gray-900 leading-relaxed">
                      <%= @current_card.front_content %>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Flip Button -->
              <%= if !@show_back do %>
                <button
                  phx-click="flip_card"
                  class="w-full mt-6 px-8 py-4 bg-blue-600 text-white text-lg font-medium rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Show Answer
                </button>
              <% end %>
            </div>

            <!-- Rating Buttons (shown when card is flipped) -->
            <%= if @show_back do %>
              <div class="grid grid-cols-4 gap-4">
                <button
                  phx-click="rate_card"
                  phx-value-rating="1"
                  class="px-6 py-4 bg-red-50 text-red-700 border-2 border-red-200 rounded-lg hover:bg-red-100 hover:border-red-300 transition-colors font-medium"
                >
                  <div class="text-sm mb-1">Again</div>
                  <div class="text-xs text-red-600">&lt;1m</div>
                </button>

                <button
                  phx-click="rate_card"
                  phx-value-rating="2"
                  class="px-6 py-4 bg-orange-50 text-orange-700 border-2 border-orange-200 rounded-lg hover:bg-orange-100 hover:border-orange-300 transition-colors font-medium"
                >
                  <div class="text-sm mb-1">Hard</div>
                  <div class="text-xs text-orange-600">&lt;6m</div>
                </button>

                <button
                  phx-click="rate_card"
                  phx-value-rating="3"
                  class="px-6 py-4 bg-blue-50 text-blue-700 border-2 border-blue-200 rounded-lg hover:bg-blue-100 hover:border-blue-300 transition-colors font-medium"
                >
                  <div class="text-sm mb-1">Good</div>
                  <div class="text-xs text-blue-600">&lt;10m</div>
                </button>

                <button
                  phx-click="rate_card"
                  phx-value-rating="4"
                  class="px-6 py-4 bg-green-50 text-green-700 border-2 border-green-200 rounded-lg hover:bg-green-100 hover:border-green-300 transition-colors font-medium"
                >
                  <div class="text-sm mb-1">Easy</div>
                  <div class="text-xs text-green-600">4d</div>
                </button>
              </div>
            <% end %>

            <!-- Stats -->
            <div class="mt-8 grid grid-cols-3 gap-4 text-center">
              <div>
                <div class="text-2xl font-bold text-gray-900"><%= @cards_reviewed %></div>
                <div class="text-sm text-gray-600">Reviewed</div>
              </div>
              <div>
                <div class="text-2xl font-bold text-gray-900"><%= @cards_mastered %></div>
                <div class="text-sm text-gray-600">Mastered</div>
              </div>
              <div>
                <div class="text-2xl font-bold text-gray-900"><%= format_duration(@session_duration) %></div>
                <div class="text-sm text-gray-600">Time</div>
              </div>
            </div>
          </div>

        <% :completed -> %>
          <!-- Session Complete Stage -->
          <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-green-100 text-green-600 mb-6">
                <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>

              <h2 class="text-3xl font-bold text-gray-900 mb-4">Session Complete!</h2>
              <p class="text-xl text-gray-600 mb-8">Great job studying!</p>

              <!-- Stats -->
              <div class="bg-white border border-gray-200 rounded-lg p-8 mb-8">
                <div class="grid grid-cols-3 gap-8">
                  <div>
                    <div class="text-4xl font-bold text-blue-600 mb-2"><%= @session.score %>%</div>
                    <div class="text-sm text-gray-600">Score</div>
                  </div>
                  <div>
                    <div class="text-4xl font-bold text-gray-900 mb-2"><%= @session.cards_reviewed %></div>
                    <div class="text-sm text-gray-600">Cards Reviewed</div>
                  </div>
                  <div>
                    <div class="text-4xl font-bold text-gray-900 mb-2"><%= format_duration(@session.session_duration_seconds) %></div>
                    <div class="text-sm text-gray-600">Total Time</div>
                  </div>
                </div>
              </div>

              <!-- Actions -->
              <div class="flex flex-col sm:flex-row gap-4 justify-center">
                <a
                  href="/flashcards"
                  class="inline-flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 transition-colors"
                >
                  Continue Studying
                </a>

                <a
                  href="/dashboard"
                  class="inline-flex items-center justify-center px-8 py-3 border border-gray-300 text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 transition-colors"
                >
                  Back to Dashboard
                </a>
              </div>
            </div>
          </div>

          <!-- Viral Prompt Modal (if present) -->
          <%= if assigns[:show_viral_modal] && assigns[:viral_prompt] do %>
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
              <div class="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                <h3 class="text-xl font-bold text-gray-900 mb-4"><%= @viral_prompt.title %></h3>
                <p class="text-gray-600 mb-6"><%= @viral_prompt.message %></p>

                <div class="flex gap-3">
                  <button class="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
                    <%= @viral_prompt.cta_text %>
                  </button>

                  <button class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                    Maybe Later
                  </button>
                </div>
              </div>
            </div>
          <% end %>
      <% end %>
    </div>
    """
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes >= 60 ->
        hours = div(minutes, 60)
        remaining_minutes = rem(minutes, 60)
        "#{hours}h #{remaining_minutes}m"

      minutes > 0 ->
        "#{minutes}m #{remaining_seconds}s"

      true ->
        "#{seconds}s"
    end
  end

  defp format_duration(_), do: "0s"
end
