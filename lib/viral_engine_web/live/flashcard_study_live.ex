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
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <%= if @stage == :deck_selection do %>
          <!-- Deck Selection Stage -->
          <div class="bg-white rounded-xl shadow-lg p-8">
            <h1 class="text-4xl font-bold text-gray-900 mb-2">📚 Flashcard Study</h1>
            <p class="text-gray-600 mb-8">Select a deck or generate one with AI</p>

            <div class="grid md:grid-cols-2 gap-4 mb-6">
              <%= for deck <- @decks do %>
                <div class="border-2 border-gray-200 rounded-lg p-4 hover:border-blue-500 hover:shadow-md transition-all cursor-pointer" phx-click="select_deck" phx-value-deck_id={deck.id}>
                  <h3 class="text-lg font-bold text-gray-900 mb-2"><%= deck.title %></h3>
                  <p class="text-sm text-gray-600 mb-3"><%= deck.description %></p>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-gray-500"><%= deck.card_count || 0 %> cards</span>
                    <span class="px-2 py-1 bg-blue-100 text-blue-700 rounded-full font-medium"><%= deck.subject %></span>
                  </div>
                </div>
              <% end %>
            </div>

            <button phx-click="show_ai_generator" class="w-full bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-semibold px-6 py-3 rounded-lg shadow-md">
              ✨ Generate AI Deck
            </button>

            <%= if @show_ai_generator do %>
              <form phx-submit="generate_ai_deck" class="mt-6 p-6 bg-purple-50 rounded-lg border-2 border-purple-200">
                <h3 class="font-bold text-gray-900 mb-4">AI Deck Generator</h3>
                <div class="space-y-3">
                  <input type="text" name="subject" placeholder="Subject (e.g., Math)" class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg" required />
                  <input type="text" name="topic" placeholder="Topic (e.g., Algebra)" class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg" required />
                  <select name="difficulty" class="w-full px-3 py-2 border-2 border-gray-300 rounded-lg">
                    <option value="1">Easy</option>
                    <option value="2" selected>Medium</option>
                    <option value="3">Hard</option>
                  </select>
                  <button type="submit" class="w-full bg-purple-600 hover:bg-purple-700 text-white font-semibold px-4 py-2 rounded-lg">
                    Generate Deck
                  </button>
                </div>
              </form>
            <% end %>
          </div>
        <% end %>

        <%= if @stage == :studying do %>
          <!-- Study Stage -->
          <div class="mb-6">
            <div class="bg-white rounded-xl shadow-lg p-4 flex items-center justify-between">
              <div>
                <h2 class="text-xl font-bold text-gray-900"><%= @deck.title %></h2>
                <p class="text-sm text-gray-600">Card <%= @current_card_index + 1 %> of <%= length(@cards) %></p>
              </div>
              <div class="text-right">
                <p class="text-2xl font-bold text-blue-600"><%= format_time(@session_duration) %></p>
                <p class="text-xs text-gray-600">Mastered: <%= @cards_mastered %></p>
              </div>
            </div>
          </div>

          <!-- Flashcard -->
          <div class="mb-6">
            <div class="bg-white rounded-2xl shadow-2xl p-12 min-h-[400px] flex flex-col items-center justify-center cursor-pointer transition-all hover:shadow-3xl" phx-click="flip_card">
              <%= if !@show_back do %>
                <div class="text-center">
                  <p class="text-sm font-medium text-gray-500 mb-4">QUESTION</p>
                  <h3 class="text-3xl font-bold text-gray-900 mb-8"><%= @current_card.front_text %></h3>
                  <p class="text-sm text-gray-400">Click to reveal answer</p>
                </div>
              <% else %>
                <div class="text-center">
                  <p class="text-sm font-medium text-gray-500 mb-4">ANSWER</p>
                  <h3 class="text-2xl font-semibold text-blue-600 mb-8"><%= @current_card.back_text %></h3>
                  <p class="text-sm text-gray-400">Rate your confidence below</p>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Rating Buttons (only show when answer is revealed) -->
          <%= if @show_back do %>
            <div class="grid grid-cols-3 gap-4">
              <button phx-click="rate_card" phx-value-rating="1" class="bg-red-500 hover:bg-red-600 text-white font-semibold py-4 rounded-lg shadow-md">
                Again
              </button>
              <button phx-click="rate_card" phx-value-rating="3" class="bg-yellow-500 hover:bg-yellow-600 text-white font-semibold py-4 rounded-lg shadow-md">
                Good
              </button>
              <button phx-click="rate_card" phx-value-rating="5" class="bg-green-500 hover:bg-green-600 text-white font-semibold py-4 rounded-lg shadow-md">
                Easy
              </button>
            </div>
          <% end %>
        <% end %>

        <%= if @stage == :completed do %>
          <!-- Completion Stage -->
          <div class="bg-white rounded-xl shadow-lg p-12 text-center">
            <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-green-100 mb-6">
              <svg class="h-12 w-12 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 class="text-3xl font-bold text-gray-900 mb-4">Session Complete!</h2>
            <div class="grid md:grid-cols-3 gap-4 my-8">
              <div class="p-4 bg-blue-50 rounded-lg">
                <p class="text-sm text-gray-600">Cards Reviewed</p>
                <p class="text-3xl font-bold text-blue-600"><%= @session.cards_reviewed %></p>
              </div>
              <div class="p-4 bg-green-50 rounded-lg">
                <p class="text-sm text-gray-600">Cards Mastered</p>
                <p class="text-3xl font-bold text-green-600"><%= @session.cards_mastered %></p>
              </div>
              <div class="p-4 bg-purple-50 rounded-lg">
                <p class="text-sm text-gray-600">Score</p>
                <p class="text-3xl font-bold text-purple-600"><%= round(@session.score || 0) %>%</p>
              </div>
            </div>
            <a href="/flashcards" class="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold px-8 py-3 rounded-lg shadow-md">
              Back to Flashcards
            </a>
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
