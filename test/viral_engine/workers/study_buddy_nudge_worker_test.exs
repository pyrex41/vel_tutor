defmodule ViralEngine.Workers.StudyBuddyNudgeWorkerTest do
  use VelTutor.DataCase, async: true

  alias ViralEngine.Workers.StudyBuddyNudgeWorker
  alias ViralEngine.{Repo, PracticeSession, StudySession, DiagnosticAssessment}

  describe "find_users_needing_study_help/0" do
    test "finds users with upcoming exams" do
      user_id = 1
      tomorrow = Date.add(Date.utc_today(), 1)

      # Create exam prep study session
      create_study_session(user_id,
        session_type: "exam_prep",
        subject: "math",
        exam_date: tomorrow,
        status: "scheduled"
      )

      users = StudyBuddyNudgeWorker.find_users_needing_study_help()

      assert Enum.any?(users, &(&1.user_id == user_id and &1.subject == "math"))
    end

    test "finds users with weak subject performance" do
      user_id = 2

      # Create multiple low-scoring practice sessions
      Enum.each(1..5, fn _ ->
        create_practice_session(user_id, subject: "math", score: 65)
      end)

      users = StudyBuddyNudgeWorker.find_users_needing_study_help()

      weak_user = Enum.find(users, &(&1.user_id == user_id and &1.subject == "math"))
      assert weak_user != nil
      assert weak_user.source == "weak_performance"
    end

    test "requires minimum 3 sessions for weak subject detection" do
      user_id = 3

      # Only 2 sessions (below threshold)
      create_practice_session(user_id, subject: "math", score: 60)
      create_practice_session(user_id, subject: "math", score: 65)

      users = StudyBuddyNudgeWorker.find_users_needing_study_help()

      assert not Enum.any?(users, &(&1.user_id == user_id))
    end

    test "excludes users with recent sessions above threshold" do
      user_id = 4

      # High scoring sessions
      Enum.each(1..5, fn _ ->
        create_practice_session(user_id, subject: "math", score: 85)
      end)

      users = StudyBuddyNudgeWorker.find_users_needing_study_help()

      assert not Enum.any?(users, &(&1.user_id == user_id and &1.subject == "math"))
    end

    test "deduplicates users appearing in multiple categories" do
      user_id = 5
      tomorrow = Date.add(Date.utc_today(), 1)

      # Both upcoming exam AND weak performance
      create_study_session(user_id,
        session_type: "exam_prep",
        subject: "math",
        exam_date: tomorrow,
        status: "scheduled"
      )

      Enum.each(1..3, fn _ ->
        create_practice_session(user_id, subject: "math", score: 65)
      end)

      users = StudyBuddyNudgeWorker.find_users_needing_study_help()
      user_count = Enum.count(users, &(&1.user_id == user_id and &1.subject == "math"))

      # Should appear only once despite meeting both criteria
      assert user_count == 1
    end
  end

  describe "identify_weak_topics/2" do
    test "extracts weak topics from diagnostic assessment" do
      user_id = 6
      subject = "math"

      # Create diagnostic with weak topics
      create_diagnostic_assessment(user_id,
        subject: subject,
        completed: true,
        results: %{
          "weak_topics" => ["Quadratic Equations", "Logarithms"]
        }
      )

      weak_topics = StudyBuddyNudgeWorker.identify_weak_topics(user_id, subject)

      assert "Quadratic Equations" in weak_topics
      assert "Logarithms" in weak_topics
    end

    test "extracts weak topics from skill heatmap" do
      user_id = 7
      subject = "science"

      create_diagnostic_assessment(user_id,
        subject: subject,
        completed: true,
        results: %{
          "skill_heatmap" => %{
            "Cellular Respiration" => 0.3,
            "Photosynthesis" => 0.8,
            "Newton's Laws" => 0.4
          }
        }
      )

      weak_topics = StudyBuddyNudgeWorker.identify_weak_topics(user_id, subject)

      # Should include low proficiency topics
      assert "Cellular Respiration" in weak_topics or "Newton's Laws" in weak_topics
    end

    test "identifies weak topics from practice session scores" do
      user_id = 8
      subject = "english"

      # Multiple low scores on same topic
      Enum.each(1..3, fn _ ->
        create_practice_session(user_id,
          subject: subject,
          score: 55,
          metadata: %{"topic" => "Essay Structure"}
        )
      end)

      create_practice_session(user_id,
        subject: subject,
        score: 65,
        metadata: %{"topic" => "Grammar Rules"}
      )

      weak_topics = StudyBuddyNudgeWorker.identify_weak_topics(user_id, subject)

      # Most frequent low-scoring topic should appear
      assert "Essay Structure" in weak_topics
    end

    test "returns default topics when no data available" do
      user_id = 999  # No data for this user
      subject = "math"

      weak_topics = StudyBuddyNudgeWorker.identify_weak_topics(user_id, subject)

      # Should return fallback topics
      assert length(weak_topics) > 0
      assert is_binary(List.first(weak_topics))
    end

    test "combines diagnostic, intelligence, and practice data" do
      user_id = 9
      subject = "math"

      # Diagnostic weak topic
      create_diagnostic_assessment(user_id,
        subject: subject,
        completed: true,
        results: %{"weak_topics" => ["Algebra"]}
      )

      # Practice weak topic
      Enum.each(1..3, fn _ ->
        create_practice_session(user_id,
          subject: subject,
          score: 60,
          metadata: %{"topic" => "Geometry"}
        )
      end)

      weak_topics = StudyBuddyNudgeWorker.identify_weak_topics(user_id, subject)

      # Should include topics from multiple sources
      assert length(weak_topics) >= 2
    end
  end

  describe "has_active_study_session?/2" do
    test "returns true when user has active exam prep session" do
      user_id = 10
      subject = "math"

      create_study_session(user_id,
        session_type: "exam_prep",
        subject: subject,
        status: "scheduled"
      )

      assert StudyBuddyNudgeWorker.has_active_study_session?(user_id, subject)
    end

    test "returns false when no active sessions exist" do
      user_id = 11
      subject = "math"

      refute StudyBuddyNudgeWorker.has_active_study_session?(user_id, subject)
    end

    test "returns false when sessions are completed" do
      user_id = 12
      subject = "math"

      create_study_session(user_id,
        session_type: "exam_prep",
        subject: subject,
        status: "completed"
      )

      refute StudyBuddyNudgeWorker.has_active_study_session?(user_id, subject)
    end

    test "checks correct subject" do
      user_id = 13

      create_study_session(user_id,
        session_type: "exam_prep",
        subject: "math",
        status: "scheduled"
      )

      # Check different subject
      refute StudyBuddyNudgeWorker.has_active_study_session?(user_id, "english")
    end
  end

  describe "recommend_study_buddies/4" do
    test "finds strong peers when no weak topics specified" do
      user_id = 14
      subject = "math"

      # Create strong peer
      peer_id = 100
      Enum.each(1..5, fn _ ->
        create_practice_session(peer_id,
          subject: subject,
          score: 90,
          inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600, :second)
        )
      end)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, [])

      peer = Enum.find(buddies, &(&1.user_id == peer_id))
      assert peer != nil
      assert peer.average_score > 75
    end

    test "finds complementary peers strong in user's weak topics" do
      user_id = 15
      subject = "math"
      weak_topics = ["Algebra", "Geometry"]

      # Create peer strong in algebra
      peer_id = 101
      Enum.each(1..4, fn _ ->
        create_practice_session(peer_id,
          subject: subject,
          score: 95,
          metadata: %{"topic" => "Algebra"},
          inserted_at: DateTime.utc_now() |> DateTime.add(-2 * 24 * 3600, :second)
        )
      end)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, weak_topics)

      assert length(buddies) > 0
      # Peer with strength match should be recommended
      assert Enum.any?(buddies, &(&1.user_id == peer_id))
    end

    test "excludes current user from recommendations" do
      user_id = 16
      subject = "math"

      # Create strong sessions for current user
      Enum.each(1..5, fn _ ->
        create_practice_session(user_id, subject: subject, score: 95)
      end)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, [])

      # Should not recommend self
      refute Enum.any?(buddies, &(&1.user_id == user_id))
    end

    test "requires minimum session count for recommendations" do
      user_id = 17
      subject = "math"

      # Peer with only 2 sessions (below minimum)
      peer_id = 102
      create_practice_session(peer_id, subject: subject, score: 90)
      create_practice_session(peer_id, subject: subject, score: 92)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, [])

      # Peer should not appear due to insufficient session count
      refute Enum.any?(buddies, &(&1.user_id == peer_id))
    end

    test "respects limit parameter" do
      user_id = 18
      subject = "math"

      # Create 10 strong peers
      Enum.each(1..10, fn i ->
        peer_id = 200 + i
        Enum.each(1..5, fn _ ->
          create_practice_session(peer_id, subject: subject, score: 85)
        end)
      end)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, [], 3)

      assert length(buddies) <= 3
    end

    test "prioritizes peers with recent activity" do
      user_id = 19
      subject = "math"

      # Recent active peer
      recent_peer_id = 103
      Enum.each(1..5, fn _ ->
        create_practice_session(recent_peer_id,
          subject: subject,
          score: 85,
          inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600, :second)
        )
      end)

      # Old inactive peer
      old_peer_id = 104
      Enum.each(1..5, fn _ ->
        create_practice_session(old_peer_id,
          subject: subject,
          score: 90,
          inserted_at: DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
        )
      end)

      buddies = StudyBuddyNudgeWorker.recommend_study_buddies(user_id, subject, [])

      # Recent peer should be included, old peer excluded
      assert Enum.any?(buddies, &(&1.user_id == recent_peer_id))
      refute Enum.any?(buddies, &(&1.user_id == old_peer_id))
    end
  end

  describe "calculate_optimal_study_time/1" do
    test "schedules session 2 days before exam at 6 PM" do
      exam_date = Date.add(Date.utc_today(), 5)

      optimal_time = StudyBuddyNudgeWorker.calculate_optimal_study_time(exam_date)

      expected_date = Date.add(exam_date, -2)
      assert DateTime.to_date(optimal_time) == expected_date
      assert optimal_time.hour == 18
      assert optimal_time.minute == 0
    end
  end

  # Helper functions

  defp create_practice_session(user_id, opts \\ []) do
    attrs = %{
      user_id: user_id,
      session_type: Keyword.get(opts, :session_type, "practice_test"),
      subject: Keyword.get(opts, :subject, "math"),
      current_step: 1,
      total_steps: 10,
      completed: Keyword.get(opts, :completed, true),
      score: Keyword.get(opts, :score, 75),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    session =
      %PracticeSession{}
      |> PracticeSession.changeset(attrs)
      |> Repo.insert!()

    if inserted_at = Keyword.get(opts, :inserted_at) do
      session
      |> Ecto.Changeset.change(inserted_at: inserted_at)
      |> Repo.update!()
    else
      session
    end
  end

  defp create_study_session(creator_id, opts \\ []) do
    subject = Keyword.get(opts, :subject, "math")

    attrs = %{
      creator_id: creator_id,
      session_name: Keyword.get(opts, :session_name, "Test Study Session"),
      subject: subject,
      session_token: StudySession.generate_token(creator_id, subject),
      session_type: Keyword.get(opts, :session_type, "group_practice"),
      status: Keyword.get(opts, :status, "scheduled"),
      exam_date: Keyword.get(opts, :exam_date)
    }

    %StudySession{}
    |> StudySession.changeset(attrs)
    |> Repo.insert!()
  end

  defp create_diagnostic_assessment(user_id, opts \\ []) do
    attrs = %{
      user_id: user_id,
      subject: Keyword.get(opts, :subject, "math"),
      grade_level: Keyword.get(opts, :grade_level, "10th"),
      total_questions: Keyword.get(opts, :total_questions, 10),
      completed: Keyword.get(opts, :completed, false),
      results: Keyword.get(opts, :results, %{})
    }

    %DiagnosticAssessment{}
    |> DiagnosticAssessment.changeset(attrs)
    |> Repo.insert!()
  end
end
