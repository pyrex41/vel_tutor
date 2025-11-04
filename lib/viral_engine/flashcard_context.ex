defmodule ViralEngine.FlashcardContext do
  @moduledoc """
  Context module for managing flashcards with spaced repetition using SM-2 algorithm.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, FlashcardDeck, Flashcard, FlashcardStudySession, FlashcardReview}
  require Logger

  # Deck management

  @doc """
  Creates a flashcard deck.
  """
  def create_deck(attrs \\ %{}) do
    %FlashcardDeck{}
    |> FlashcardDeck.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a deck by ID with preloaded flashcards.
  """
  def get_deck(id) do
    Repo.get(FlashcardDeck, id)
    |> Repo.preload(:flashcards)
  end

  @doc """
  Gets a user's deck.
  """
  def get_user_deck(deck_id, user_id) do
    from(d in FlashcardDeck,
      where: d.id == ^deck_id and (d.user_id == ^user_id or d.is_public == true)
    )
    |> Repo.one()
    |> Repo.preload(:flashcards)
  end

  @doc """
  Lists user's decks.
  """
  def list_user_decks(user_id) do
    from(d in FlashcardDeck,
      where: d.user_id == ^user_id,
      order_by: [desc: d.updated_at],
      preload: [:flashcards]
    )
    |> Repo.all()
  end

  @doc """
  Lists public decks.
  """
  def list_public_decks(opts \\ []) do
    limit = opts[:limit] || 20
    subject = opts[:subject]

    query = from(d in FlashcardDeck,
      where: d.is_public == true,
      order_by: [desc: d.updated_at],
      limit: ^limit,
      preload: [:flashcards]
    )

    query = if subject, do: where(query, [d], d.subject == ^subject), else: query

    Repo.all(query)
  end

  # Flashcard management

  @doc """
  Creates a flashcard.
  """
  def create_flashcard(attrs \\ %{}) do
    %Flashcard{}
    |> Flashcard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates multiple flashcards for a deck.
  """
  def create_flashcards(deck_id, flashcards_data) when is_list(flashcards_data) do
    flashcards =
      Enum.with_index(flashcards_data, 1)
      |> Enum.map(fn {card_data, position} ->
        attrs = Map.merge(card_data, %{flashcard_deck_id: deck_id, position: position})

        %Flashcard{}
        |> Flashcard.changeset(attrs)
        |> Repo.insert!()
      end)

    {:ok, flashcards}
  end

  @doc """
  Generates AI flashcards for a topic (simplified - ready for MCP integration).
  """
  def generate_ai_deck(user_id, subject, topic, difficulty \\ 5, count \\ 10) do
    # Create deck
    {:ok, deck} = create_deck(%{
      user_id: user_id,
      title: "#{topic} - AI Generated",
      description: "AI-generated flashcards for #{topic}",
      subject: subject,
      difficulty: difficulty,
      is_ai_generated: true
    })

    # Generate sample flashcards (in production, this would call MCP agent)
    flashcards_data = generate_sample_flashcards(subject, topic, count)
    {:ok, flashcards} = create_flashcards(deck.id, flashcards_data)

    {:ok, %{deck: deck, flashcards: flashcards}}
  end

  # Study session management

  @doc """
  Creates a study session.
  """
  def create_study_session(attrs \\ %{}) do
    %FlashcardStudySession{}
    |> FlashcardStudySession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a study session with reviews.
  """
  def get_study_session(id) do
    Repo.get(FlashcardStudySession, id)
    |> Repo.preload([:deck, :reviews])
  end

  @doc """
  Gets a user's study session.
  """
  def get_user_study_session(session_id, user_id) do
    from(s in FlashcardStudySession,
      where: s.id == ^session_id and s.user_id == ^user_id
    )
    |> Repo.one()
    |> Repo.preload([:deck, :reviews])
  end

  @doc """
  Updates a study session.
  """
  def update_study_session(%FlashcardStudySession{} = session, attrs) do
    session
    |> FlashcardStudySession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Records a flashcard review with spaced repetition calculation.
  """
  def record_review(attrs) do
    user_id = attrs[:user_id]
    flashcard_id = attrs[:flashcard_id]
    rating = attrs[:rating]

    # Get previous review for this user/flashcard
    previous_review = get_latest_review(user_id, flashcard_id)

    # Calculate new spaced repetition values using SM-2
    sr_data = calculate_spaced_repetition(previous_review, rating)

    # Merge with attrs
    review_attrs = Map.merge(attrs, sr_data)

    %FlashcardReview{}
    |> FlashcardReview.changeset(review_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets cards due for review today.
  """
  def get_due_cards(user_id, deck_id) do
    today = Date.utc_today()

    # Get all cards in deck
    deck = get_deck(deck_id)
    all_card_ids = Enum.map(deck.flashcards, & &1.id)

    # Get latest review for each card
    reviews_by_card =
      from(r in FlashcardReview,
        where: r.user_id == ^user_id and r.flashcard_id in ^all_card_ids,
        order_by: [desc: r.inserted_at],
        distinct: r.flashcard_id
      )
      |> Repo.all()
      |> Enum.group_by(& &1.flashcard_id)

    # Filter cards that are due today or never reviewed
    due_cards =
      Enum.filter(deck.flashcards, fn card ->
        case Map.get(reviews_by_card, card.id) do
          nil -> true  # Never reviewed
          [review | _] ->
            review.next_review_date && Date.compare(review.next_review_date, today) != :gt
        end
      end)

    due_cards
  end

  @doc """
  Completes a study session and calculates score.
  """
  def complete_study_session(session_id) do
    session = get_study_session(session_id)

    if session do
      mastered_count = Enum.count(session.reviews, & &1.is_mastered)
      total_count = session.cards_reviewed

      score = if total_count > 0, do: round(mastered_count / total_count * 100), else: 0

      update_study_session(session, %{
        completed: true,
        score: score,
        cards_mastered: mastered_count
      })
    else
      {:error, :not_found}
    end
  end

  # Private functions

  defp get_latest_review(user_id, flashcard_id) do
    from(r in FlashcardReview,
      where: r.user_id == ^user_id and r.flashcard_id == ^flashcard_id,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Calculates spaced repetition values using SM-2 algorithm.
  Rating: 1=again, 2=hard, 3=good, 4=easy, 5=very easy
  """
  defp calculate_spaced_repetition(previous_review, rating) do
    # Get previous values or defaults
    ease_factor = if previous_review, do: previous_review.ease_factor, else: 2.5
    repetitions = if previous_review, do: previous_review.repetitions, else: 0
    interval = if previous_review, do: previous_review.interval_days, else: 0

    # Calculate new ease factor
    new_ease = max(1.3, ease_factor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02)))

    # Calculate new interval and repetitions based on rating
    {new_interval, new_repetitions} =
      cond do
        rating < 3 ->
          # Failed - reset
          {1, 0}

        repetitions == 0 ->
          # First successful repetition
          {1, 1}

        repetitions == 1 ->
          # Second successful repetition
          {6, 2}

        true ->
          # Subsequent repetitions
          {round(interval * new_ease), repetitions + 1}
      end

    # Calculate next review date
    next_review = Date.add(Date.utc_today(), new_interval)

    # Determine if mastered (5+ successful repetitions with interval > 21 days)
    is_mastered = new_repetitions >= 5 && new_interval > 21

    %{
      ease_factor: new_ease,
      interval_days: new_interval,
      repetitions: new_repetitions,
      next_review_date: next_review,
      is_mastered: is_mastered
    }
  end

  # Sample flashcard generation (simplified - for MCP integration)
  defp generate_sample_flashcards("math", topic, count) do
    Enum.map(1..count, fn i ->
      %{
        front: "Math problem #{i}: What is #{i * 2} + #{i * 3}?",
        back: "Answer: #{i * 5}",
        hint: "Think about addition",
        tags: [topic, "arithmetic"]
      }
    end)
  end

  defp generate_sample_flashcards("vocabulary", topic, count) do
    sample_words = ["Ephemeral", "Ubiquitous", "Serendipity", "Paradigm", "Ambiguous",
                    "Eloquent", "Pragmatic", "Resilient", "Verbose", "Zealous"]

    Enum.take(sample_words, count)
    |> Enum.map(fn word ->
      %{
        front: word,
        back: "Definition of #{word} (placeholder - would be AI generated)",
        hint: "Think about the context",
        tags: [topic, "vocabulary"]
      }
    end)
  end

  defp generate_sample_flashcards(_subject, topic, count) do
    Enum.map(1..count, fn i ->
      %{
        front: "Question #{i} about #{topic}",
        back: "Answer #{i} (AI generated content here)",
        tags: [topic]
      }
    end)
  end
end
