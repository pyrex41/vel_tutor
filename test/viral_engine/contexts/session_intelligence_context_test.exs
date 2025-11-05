defmodule ViralEngine.SessionIntelligenceContextTest do
  use VelTutor.DataCase, async: true

  alias ViralEngine.SessionIntelligenceContext
  alias ViralEngine.PracticeSession
  alias VelTutor.Repo

  describe "analyze_learning_patterns/1" do
    test "returns empty patterns when user has no sessions" do
      {:ok, patterns} = SessionIntelligenceContext.analyze_learning_patterns(user_id: 999)

      assert patterns.total_sessions == 0
      assert patterns.peak_hours == []
      assert patterns.optimal_duration_minutes == 25
      assert patterns.consistency_score == 0.0
    end

    test "identifies peak performance hours from session data" do
      user_id = 1
      # Create sessions at different hours with varying scores
      create_session(user_id, score: 90, hour: 14)
      create_session(user_id, score: 92, hour: 14)
      create_session(user_id, score: 75, hour: 10)
      create_session(user_id, score: 85, hour: 15)

      {:ok, patterns} = SessionIntelligenceContext.analyze_learning_patterns(user_id: user_id)

      assert 14 in patterns.peak_hours
      assert patterns.total_sessions == 4
    end

    test "calculates consistency score based on study frequency" do
      user_id = 2
      # Create sessions on different days
      Enum.each(1..7, fn days_ago ->
        create_session(user_id, inserted_at: DateTime.utc_now() |> DateTime.add(-days_ago * 24 * 3600, :second))
      end)

      {:ok, patterns} = SessionIntelligenceContext.analyze_learning_patterns(user_id: user_id, days: 30)

      # 7 unique days out of 30
      assert patterns.consistency_score > 0.2
      assert patterns.consistency_score < 0.25
    end

    test "calculates subject affinity scores" do
      user_id = 3
      create_session(user_id, subject: "math", score: 90)
      create_session(user_id, subject: "math", score: 85)
      create_session(user_id, subject: "english", score: 70)

      {:ok, patterns} = SessionIntelligenceContext.analyze_learning_patterns(user_id: user_id)

      assert patterns.subject_affinity["math"] > patterns.subject_affinity["english"]
      assert patterns.avg_score > 80
    end
  end

  describe "analyze_performance_trends/1" do
    test "returns empty trends when no data available" do
      {:ok, trends} = SessionIntelligenceContext.analyze_performance_trends(user_id: 999)

      assert trends.direction == :unknown
      assert trends.current_score == nil
    end

    test "detects improving trend from increasing scores" do
      user_id = 4
      # Create sessions with improving scores
      Enum.each(1..10, fn i ->
        create_session(user_id, score: 50 + (i * 3), inserted_at: DateTime.utc_now() |> DateTime.add(-i * 24 * 3600, :second))
      end)

      {:ok, trends} = SessionIntelligenceContext.analyze_performance_trends(user_id: user_id)

      assert trends.direction == :improving
      assert trends.velocity > 0
    end

    test "detects declining trend from decreasing scores" do
      user_id = 5
      # Create sessions with declining scores
      Enum.each(1..10, fn i ->
        create_session(user_id, score: 80 - (i * 3), inserted_at: DateTime.utc_now() |> DateTime.add(-i * 24 * 3600, :second))
      end)

      {:ok, trends} = SessionIntelligenceContext.analyze_performance_trends(user_id: user_id)

      assert trends.direction == :declining
      assert trends.velocity < 0
    end

    test "filters by subject when provided" do
      user_id = 6
      create_session(user_id, subject: "math", score: 90)
      create_session(user_id, subject: "english", score: 60)

      {:ok, trends} = SessionIntelligenceContext.analyze_performance_trends(user_id: user_id, subject: "math")

      # Should only consider math sessions
      assert trends.current_score == 90
    end
  end

  describe "identify_weak_topics/1" do
    test "returns empty list when no sessions exist" do
      {:ok, topics} = SessionIntelligenceContext.identify_weak_topics(user_id: 999, subject: "math")

      assert topics == []
    end

    test "identifies topics with low scores as weak" do
      user_id = 7
      # Create sessions with topic metadata
      create_session(user_id, subject: "math", score: 45, metadata: %{"topic" => "Quadratic Equations"})
      create_session(user_id, subject: "math", score: 50, metadata: %{"topic" => "Quadratic Equations"})
      create_session(user_id, subject: "math", score: 90, metadata: %{"topic" => "Linear Equations"})

      {:ok, topics} = SessionIntelligenceContext.identify_weak_topics(user_id: user_id, subject: "math", limit: 5)

      weak_topic_names = Enum.map(topics, & &1.topic)
      assert "Quadratic Equations" in weak_topic_names
    end

    test "limits results to specified number" do
      user_id = 8
      Enum.each(1..10, fn i ->
        create_session(user_id, subject: "math", score: 50, metadata: %{"topic" => "Topic #{i}"})
      end)

      {:ok, topics} = SessionIntelligenceContext.identify_weak_topics(user_id: user_id, subject: "math", limit: 3)

      assert length(topics) <= 3
    end
  end

  describe "calculate_session_effectiveness/1" do
    test "returns error when session not found" do
      result = SessionIntelligenceContext.calculate_session_effectiveness(session_id: 99999)

      assert result == {:error, :session_not_found_or_incomplete}
    end

    test "calculates effectiveness metrics for completed session" do
      user_id = 9
      # Create baseline sessions
      Enum.each(1..5, fn _ ->
        create_session(user_id, subject: "math", score: 70)
      end)

      # Create test session with higher score
      session = create_session(user_id, subject: "math", score: 85, timer_seconds: 1200)

      {:ok, effectiveness} = SessionIntelligenceContext.calculate_session_effectiveness(session_id: session.id)

      assert effectiveness.overall_score > 0
      assert effectiveness.improvement_score > 0
      assert effectiveness.time_efficiency > 0
      assert effectiveness.completion_rate == 1.0
    end
  end

  describe "generate_recommendations/1" do
    test "generates recommendations based on analytics" do
      user_id = 10
      # Create session history
      Enum.each(1..10, fn i ->
        create_session(user_id,
          subject: "math",
          score: 70 + i,
          metadata: %{"topic" => if(i < 5, do: "Algebra", else: "Geometry")},
          hour: 14
        )
      end)

      {:ok, recommendations} = SessionIntelligenceContext.generate_recommendations(user_id: user_id)

      assert recommendations.next_topic != nil
      assert recommendations.recommended_duration > 0
      assert is_list(recommendations.study_methods)
    end

    test "suggests appropriate difficulty adjustments" do
      user_id = 11
      # Create improving trend
      Enum.each(1..10, fn i ->
        create_session(user_id, score: 50 + (i * 4))
      end)

      {:ok, recommendations} = SessionIntelligenceContext.generate_recommendations(user_id: user_id)

      # Should suggest increase for improving trend
      assert recommendations.difficulty_adjustment in [:increase_slightly, :maintain]
    end
  end

  describe "compare_to_peers/1" do
    test "calculates percentile rank among peers" do
      # Create user with score of 85
      user_id = 12
      create_session(user_id, score: 85)

      # Create peer sessions with lower scores
      Enum.each(1..10, fn peer_id ->
        create_session(1000 + peer_id, score: 70)
      end)

      {:ok, comparison} = SessionIntelligenceContext.compare_to_peers(user_id: user_id, grade_level: 10)

      # User should be in high percentile
      assert comparison.overall_percentile > 50
    end

    test "handles insufficient peer data gracefully" do
      {:ok, comparison} = SessionIntelligenceContext.compare_to_peers(user_id: 999, grade_level: 10)

      # Should return gracefully when no peers exist
      assert is_map(comparison)
    end
  end

  # Helper functions

  defp create_session(user_id, opts \\ []) do
    attrs = %{
      user_id: user_id,
      session_type: Keyword.get(opts, :session_type, "practice_test"),
      subject: Keyword.get(opts, :subject, "math"),
      current_step: 1,
      total_steps: 10,
      timer_seconds: Keyword.get(opts, :timer_seconds, 600),
      completed: Keyword.get(opts, :completed, true),
      score: Keyword.get(opts, :score, 75),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    session =
      %PracticeSession{}
      |> PracticeSession.changeset(attrs)
      |> Repo.insert!()

    # Update inserted_at if provided
    if inserted_at = Keyword.get(opts, :inserted_at) do
      session
      |> Ecto.Changeset.change(inserted_at: inserted_at)
      |> Repo.update!()
    else
      # Update with specific hour if provided
      if hour = Keyword.get(opts, :hour) do
        now = DateTime.utc_now()
        datetime = DateTime.new!(Date.utc_today(), Time.new!(hour, 0, 0))

        session
        |> Ecto.Changeset.change(inserted_at: datetime)
        |> Repo.update!()
      else
        session
      end
    end
  end
end
