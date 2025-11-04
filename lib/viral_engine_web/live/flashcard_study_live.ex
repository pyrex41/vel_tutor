defmodule ViralEngineWeb.FlashcardStudyLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{FlashcardContext, AchievementContext, ViralPrompts, StreakContext}
  require Logger

  on_mount ViralEngineWeb.Live.ViralPromptsHook

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
  def handle_event("generate_ai_deck", %{"subject" => subject, "topic" => topic, "difficulty" => difficulty}, socket) do
    diff = String.to_integer(difficulty)

    case FlashcardContext.generate_ai_deck(socket.assigns.user.id, subject, topic, diff, 10) do
      {:ok, %{deck: deck}} ->
        {:noreply,
         socket
         |> put_flash(:success, "AI deck generated! #{deck.title}")
         |> redirect(to: "/flashcards/study/#{deck.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate deck")}
    end
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
    cards_mastered = if review.is_mastered, do: socket.assigns.cards_mastered + 1, else: socket.assigns.cards_mastered

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

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  defp get_rating_text(rating) do
    case rating do
      1 -> "Again"
      2 -> "Hard"
      3 -> "Good"
      4 -> "Easy"
      5 -> "Very Easy"
      _ -> "Rate"
    end
  end

  defp get_rating_color(rating) do
    case rating do
      1 -> "bg-red-500"
      2 -> "bg-orange-500"
      3 -> "bg-yellow-500"
      4 -> "bg-green-500"
      5 -> "bg-blue-500"
      _ -> "bg-gray-500"
    end
  end

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
end
