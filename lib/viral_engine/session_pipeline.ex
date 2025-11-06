defmodule ViralEngine.SessionPipeline do
  @moduledoc """
  Oban worker for processing tutoring sessions through the intelligence pipeline.

  Pipeline stages:
  1. Transcription (stubbed for now, will integrate with AssemblyAI)
  2. AI Summarization using AIClient with multi-provider routing
  3. Action Generation for students, tutors, and parents
  4. TrustSafety verification
  5. Database updates and event triggering
  """

  use Oban.Worker,
    queue: :session_processing,
    max_attempts: 3,
    priority: 1

  require Logger
  alias ViralEngine.{Repo, TutoringSession, AIClient, Agents.TrustSafety}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"session_id" => session_id}}) do
    Logger.info("Processing session #{session_id}")

    with {:ok, session} <- fetch_session(session_id),
         {:ok, transcript} <- get_or_generate_transcript(session),
         {:ok, summary} <- summarize_session(transcript, session),
         {:ok, actions} <- generate_actions(summary, session),
         {:ok, verified_actions} <- verify_actions_with_trust_safety(actions, session),
         {:ok, _updated_session} <- update_session(session, summary, verified_actions) do
      Logger.info("Successfully processed session #{session_id}")
      {:ok, :completed}
    else
      {:error, reason} = error ->
        Logger.error("Failed to process session #{session_id}: #{inspect(reason)}")
        error
    end
  end

  # Fetch session from database
  defp fetch_session(session_id) do
    case Repo.get(TutoringSession, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        {:ok, session}
    end
  end

  # Get existing transcript or generate stub (placeholder for AssemblyAI integration)
  defp get_or_generate_transcript(session) do
    if session.transcript_text do
      {:ok, session.transcript_text}
    else
      # Stub transcription - in production, this would call AssemblyAI
      transcript = generate_stub_transcript(session)
      Logger.info("Generated stub transcript for session #{session.id}")
      {:ok, transcript}
    end
  end

  defp generate_stub_transcript(session) do
    """
    [Stub Transcript for Session #{session.id}]
    Subject: #{session.subject || "General"}
    Topic: #{session.topic || "N/A"}
    Duration: #{session.duration_minutes || 0} minutes

    Student: Hi, I need help with #{session.topic || "this topic"}.
    Tutor: Sure! Let's go through it step by step.
    Student: That makes sense now, thank you!
    Tutor: Great! Let me know if you have any other questions.

    [End of transcript]
    """
  end

  # Summarize session using AIClient with intelligent routing
  defp summarize_session(transcript, session) do
    # Determine task complexity based on session characteristics
    task_type = determine_task_type(session)

    prompt = build_summarization_prompt(transcript, session)

    case AIClient.chat(prompt, task_type: task_type, temperature: 0.7) do
      {:ok, response} ->
        Logger.info(
          "Session summarized using #{response.provider}/#{response.model} (cost: $#{response.cost})"
        )

        {:ok, response.content}

      {:error, reason} ->
        Logger.error("AI summarization failed: #{inspect(reason)}")
        {:error, :summarization_failed}
    end
  end

  defp determine_task_type(session) do
    # Use :planning (GPT-4o) for complex sessions requiring deep educational insights
    # Use :general for simpler sessions
    cond do
      session.duration_minutes && session.duration_minutes > 45 ->
        :planning

      session.rating && session.rating <= 2 ->
        # Low-rated sessions need careful analysis
        :planning

      session.subject in ["mathematics", "physics", "chemistry"] ->
        # STEM subjects benefit from GPT-4o's reasoning
        :planning

      true ->
        :general
    end
  end

  defp build_summarization_prompt(transcript, session) do
    """
    You are an educational AI analyzing a tutoring session. Provide a comprehensive summary.

    Session Details:
    - Subject: #{session.subject || "Not specified"}
    - Topic: #{session.topic || "Not specified"}
    - Duration: #{session.duration_minutes || 0} minutes
    - Rating: #{session.rating || "Not rated"}

    Transcript:
    #{transcript}

    Please provide a structured summary including:
    1. Session Overview (2-3 sentences)
    2. Key Concepts Covered (bullet points)
    3. Student Understanding Level (1-5 scale with explanation)
    4. Tutor Effectiveness (1-5 scale with explanation)
    5. Recommended Next Steps for Student
    6. Recommended Actions for Tutor
    7. Suggested Parent Communication Points

    Format your response as JSON with these exact keys:
    {
      "overview": "...",
      "concepts": ["...", "..."],
      "student_level": 4,
      "student_level_notes": "...",
      "tutor_effectiveness": 5,
      "tutor_effectiveness_notes": "...",
      "student_next_steps": ["...", "..."],
      "tutor_actions": ["...", "..."],
      "parent_points": ["...", "..."]
    }
    """
  end

  # Generate actionable recommendations
  defp generate_actions(summary_json, session) do
    case Jason.decode(summary_json) do
      {:ok, summary} ->
        actions = %{
          student_actions: build_student_actions(summary, session),
          tutor_actions: build_tutor_actions(summary, session),
          parent_actions: build_parent_actions(summary, session)
        }

        {:ok, actions}

      {:error, _} ->
        # Fallback if JSON parsing fails
        Logger.warning("Failed to parse summary JSON, using fallback actions")

        actions = %{
          student_actions: [%{type: "review", content: "Review session materials"}],
          tutor_actions: [%{type: "follow_up", content: "Schedule follow-up session"}],
          parent_actions: [%{type: "notify", content: "Session completed successfully"}]
        }

        {:ok, actions}
    end
  end

  defp build_student_actions(summary, _session) do
    next_steps = summary["student_next_steps"] || []

    Enum.map(next_steps, fn step ->
      %{
        type: "recommendation",
        content: step,
        priority: determine_priority(step)
      }
    end)
  end

  defp build_tutor_actions(summary, session) do
    tutor_actions = summary["tutor_actions"] || []

    actions =
      Enum.map(tutor_actions, fn action ->
        %{
          type: "task",
          content: action,
          session_id: session.id
        }
      end)

    # Add follow-up action if session rating is low
    if session.rating && session.rating <= 2 do
      actions ++
        [
          %{
            type: "urgent_follow_up",
            content:
              "Session received low rating (#{session.rating}/5). Please reach out to student.",
            priority: "high"
          }
        ]
    else
      actions
    end
  end

  defp build_parent_actions(summary, session) do
    parent_points = summary["parent_points"] || []

    [
      %{
        type: "weekly_recap",
        content: "Add to weekly progress report",
        highlights: parent_points,
        session_id: session.id
      }
    ]
  end

  defp determine_priority(step) do
    cond do
      String.contains?(String.downcase(step), ["urgent", "immediately", "asap"]) ->
        "high"

      String.contains?(String.downcase(step), ["review", "practice"]) ->
        "medium"

      true ->
        "normal"
    end
  end

  # Verify all generated actions through TrustSafety
  defp verify_actions_with_trust_safety(actions, session) do
    verified_actions = %{
      student_actions: verify_action_list(actions.student_actions, :student, session),
      tutor_actions: verify_action_list(actions.tutor_actions, :tutor, session),
      parent_actions: verify_action_list(actions.parent_actions, :parent, session)
    }

    {:ok, verified_actions}
  end

  defp verify_action_list(action_list, actor_type, session) do
    Enum.filter(action_list, fn action ->
      context = %{
        user_id: get_user_id_for_actor(actor_type, session),
        action_type: action.type,
        content: action.content,
        session_id: session.id
      }

      case TrustSafety.check_action(context) do
        {:ok, :allowed} ->
          true

        {:error, reason} ->
          Logger.warning(
            "Action blocked by TrustSafety: #{inspect(action)} - Reason: #{inspect(reason)}"
          )

          false
      end
    end)
  end

  defp get_user_id_for_actor(:student, session), do: session.student_id
  defp get_user_id_for_actor(:tutor, session), do: session.tutor_id

  defp get_user_id_for_actor(:parent, session) do
    # Look up parent_id from student
    case Repo.get(ViralEngine.Accounts.User, session.student_id) do
      nil -> nil
      student -> student.parent_id
    end
  end

  # Update session in database with results
  defp update_session(session, summary, actions) do
    changeset =
      TutoringSession.changeset(session, %{
        ai_summary: summary,
        student_actions: actions.student_actions,
        tutor_actions: actions.tutor_actions,
        parent_actions: actions.parent_actions,
        processed: true,
        processed_at: DateTime.utc_now()
      })

    case Repo.update(changeset) do
      {:ok, updated_session} ->
        # Trigger events for downstream processing
        trigger_session_processed_event(updated_session)
        {:ok, updated_session}

      {:error, changeset} ->
        Logger.error("Failed to update session: #{inspect(changeset.errors)}")
        {:error, :update_failed}
    end
  end

  defp trigger_session_processed_event(session) do
    # Publish event for other systems (e.g., Orchestrator, Analytics)
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "session_events",
      {:session_processed, session}
    )

    # If session has high rating, trigger TutorSpotlight loop
    if session.rating && session.rating >= 5 do
      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "viral_loops",
        {:trigger_tutor_spotlight, session}
      )
    end
  end
end
