defmodule ViralEngine.Workers.PrepPackWorker do
  @moduledoc """
  Oban worker that automatically generates prep packs after
  practice sessions to help students prepare for next session.
  """

  use Oban.Worker,
    queue: :prep_packs,
    max_attempts: 3

  alias ViralEngine.{Repo, PrepPack, ViralPrompts}
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"student_id" => student_id, "session_id" => session_id}}) do
    Logger.info("Generating prep pack for student #{student_id} after session #{session_id}")

    case generate_prep_pack(student_id, session_id) do
      {:ok, prep_pack} ->
        Logger.info("Successfully generated prep pack: #{prep_pack.pack_token}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate prep pack: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueues a prep pack generation job after session completion.
  """
  def enqueue(student_id, session_id) do
    %{
      student_id: student_id,
      session_id: session_id
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Generates a personalized prep pack for the next session.
  """
  def generate_prep_pack(student_id, session_id) do
    # Get session details
    # In production: session = PracticeContext.get_session(session_id)

    # Simulated session data
    session = %{
      id: session_id,
      subject: "Math",
      grade_level: 8,
      score: 75,
      weak_areas: ["Quadratic Equations", "Polynomial Factoring"],
      completed_at: DateTime.utc_now()
    }

    # Analyze performance and identify weak topics
    weak_topics = identify_weak_topics(student_id, session)

    # Get AI recommendations for improvement
    ai_recommendations = generate_ai_recommendations(student_id, session, weak_topics)

    # Curate resources for weak topics
    resources = curate_resources(session.subject, weak_topics)

    # Estimate time needed
    estimated_time = calculate_estimated_time(weak_topics, resources)

    pack_attrs = %{
      student_id: student_id,
      pack_token: PrepPack.generate_token(student_id, session.subject),
      pack_name: "Next Session Prep: #{session.subject}",
      subject: session.subject,
      grade_level: session.grade_level,
      target_topics: weak_topics,
      pack_type: "practice_prep",
      resources: resources,
      ai_recommendations: ai_recommendations,
      estimated_time_minutes: estimated_time,
      expires_at: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second),  # 7 days
      metadata: %{
        session_id: session_id,
        score: session.score,
        auto_generated: true
      }
    }

    case Repo.insert(PrepPack.changeset(%PrepPack{}, pack_attrs)) do
      {:ok, prep_pack} ->
        # Trigger viral prompt to share prep pack
        trigger_prep_pack_prompt(student_id, prep_pack)

        {:ok, prep_pack}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Private helper functions

  defp identify_weak_topics(_student_id, session) do
    # In production, analyze:
    # 1. Questions answered incorrectly in this session
    # 2. Historical weak areas from past sessions
    # 3. Topics with low scores

    # For now, return simulated weak topics
    session.weak_areas || ["General Review"]
  end

  defp generate_ai_recommendations(_student_id, session, weak_topics) do
    # In production, call AI service to generate personalized recommendations

    _topics_text = Enum.join(weak_topics, ", ")

    """
    Great job on your #{session.subject} practice! Here's what to focus on for next time:

    📚 Key Areas to Review:
    #{Enum.map_join(weak_topics, "\n", fn topic -> "• #{topic}" end)}

    💡 Study Tips:
    • Start with the fundamentals of #{Enum.at(weak_topics, 0)}
    • Practice 2-3 problems per topic before the next session
    • Review your notes and any mistakes from today's session
    • Watch the recommended videos for visual explanations

    🎯 Goal for Next Session:
    Improve your #{session.subject} score by focusing on these specific areas.
    Aim for #{min(100, session.score + 10)}% or higher!

    ⏱️ Recommended Study Time: #{calculate_estimated_time(weak_topics, %{})} minutes
    """
  end

  defp curate_resources(_subject, weak_topics) do
    # In production, query a resource database or call external APIs

    # Simulated resources
    %{
      study_guides: Enum.map(weak_topics, fn topic ->
        %{
          title: "#{topic} Study Guide",
          url: "/resources/study-guides/#{String.downcase(String.replace(topic, " ", "-"))}",
          type: "pdf"
        }
      end),
      practice_problems: Enum.map(weak_topics, fn topic ->
        %{
          title: "#{topic} Practice Problems",
          url: "/resources/practice/#{String.downcase(String.replace(topic, " ", "-"))}",
          count: 10
        }
      end),
      video_links: Enum.map(weak_topics, fn topic ->
        %{
          title: "#{topic} Explained",
          url: "https://www.youtube.com/watch?v=example",
          duration_minutes: 15
        }
      end),
      flashcard_decks: Enum.map(weak_topics, fn topic ->
        %{
          title: "#{topic} Flashcards",
          url: "/flashcards/deck/#{String.downcase(String.replace(topic, " ", "-"))}",
          card_count: 20
        }
      end)
    }
  end

  defp calculate_estimated_time(weak_topics, resources) do
    # Base time per topic
    base_time = length(weak_topics) * 10  # 10 min per topic

    # Add video time
    video_time = if resources[:video_links] do
      Enum.sum(Enum.map(resources[:video_links], & &1[:duration_minutes] || 15))
    else
      length(weak_topics) * 15
    end

    # Add practice problem time (2 min per problem)
    practice_time = if resources[:practice_problems] do
      Enum.sum(Enum.map(resources[:practice_problems], & &1[:count] || 10)) * 2
    else
      length(weak_topics) * 20
    end

    min(120, base_time + video_time + practice_time)  # Cap at 2 hours
  end

  defp trigger_prep_pack_prompt(student_id, prep_pack) do
    event_data = %{
      prep_pack_id: prep_pack.id,
      pack_token: prep_pack.pack_token,
      pack_name: prep_pack.pack_name,
      target_topics: prep_pack.target_topics,
      estimated_time: prep_pack.estimated_time_minutes
    }

    case ViralPrompts.trigger_prompt(:prep_pack_ready, student_id, event_data) do
      {:ok, _prompt} ->
        Logger.info("Triggered prep pack prompt for student #{student_id}")
        ViralPrompts.broadcast_event(:prep_pack_ready, student_id, event_data)

      {:throttled, reason} ->
        Logger.debug("Prep pack prompt throttled for student #{student_id}: #{reason}")

      {:no_prompt, reason} ->
        Logger.debug("No prep pack prompt for student #{student_id}: #{reason}")
    end
  end
end
