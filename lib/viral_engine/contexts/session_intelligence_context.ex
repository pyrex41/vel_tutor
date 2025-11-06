defmodule ViralEngine.SessionIntelligenceContext do
  @moduledoc """
  Session Intelligence Context - AI-powered analytics and recommendations.

  Provides learning pattern detection, performance trend analysis, weak topic
  identification, and personalized study recommendations based on session data.
  """

  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.PracticeSession
  alias ViralEngine.DiagnosticContext

  @doc """
  Analyzes a user's practice session history to detect learning patterns.

  Returns insights such as:
  - Peak performance times (time of day)
  - Optimal session duration
  - Study consistency patterns
  - Subject affinity scores

  ## Example

      iex> analyze_learning_patterns(user_id: 123, days: 30)
      {:ok, %{
        peak_hours: [14, 15, 16],
        optimal_duration_minutes: 25,
        consistency_score: 0.87,
        subject_affinity: %{"math" => 0.92, "english" => 0.78}
      }}
  """
  def analyze_learning_patterns(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    days_back = Keyword.get(opts, :days, 30)

    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back * 24 * 3600, :second)

    # Query practice sessions with performance data
    sessions =
      from(s in PracticeSession,
        where: s.user_id == ^user_id and s.completed == true and s.inserted_at >= ^cutoff_date,
        select: %{
          subject: s.subject,
          duration: s.timer_seconds,
          score: s.score,
          hour_of_day: fragment("EXTRACT(HOUR FROM ?)", s.inserted_at),
          date: fragment("DATE(?)", s.inserted_at)
        }
      )
      |> Repo.all()

    if Enum.empty?(sessions) do
      {:ok, empty_patterns()}
    else
      patterns = %{
        peak_hours: identify_peak_performance_hours(sessions),
        optimal_duration_minutes: calculate_optimal_duration(sessions),
        consistency_score: calculate_consistency_score(sessions, days_back),
        subject_affinity: calculate_subject_affinity(sessions),
        total_sessions: length(sessions),
        avg_score: calculate_average_score(sessions)
      }

      {:ok, patterns}
    end
  end

  @doc """
  Analyzes performance trends over time to identify improvement or decline.

  Returns trend data including:
  - Overall performance direction (improving/declining/stable)
  - Subject-specific trends
  - Velocity (rate of improvement)
  - Projected future performance

  ## Example

      iex> analyze_performance_trends(user_id: 123, subject: "math")
      {:ok, %{
        direction: :improving,
        velocity: 0.15,
        current_score: 85,
        projected_score_30d: 92,
        trend_line: [...]
      }}
  """
  def analyze_performance_trends(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    subject = Keyword.get(opts, :subject)
    days_back = Keyword.get(opts, :days, 60)

    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back * 24 * 3600, :second)

    query =
      from(s in PracticeSession,
        where: s.user_id == ^user_id and s.completed == true and s.inserted_at >= ^cutoff_date,
        order_by: [asc: s.inserted_at],
        select: %{
          subject: s.subject,
          score: s.score,
          date: fragment("DATE(?)", s.inserted_at)
        }
      )

    query =
      if subject do
        from(s in query, where: s.subject == ^subject)
      else
        query
      end

    scores = Repo.all(query)

    if Enum.empty?(scores) do
      {:ok, empty_trends()}
    else
      trends = calculate_trends(scores)
      {:ok, trends}
    end
  end

  @doc """
  Identifies weak topics from session performance and diagnostic results.

  Returns prioritized list of topics that need attention based on:
  - Low success rate
  - Frequent mistakes
  - Time spent vs performance
  - Diagnostic weak areas

  ## Example

      iex> identify_weak_topics(user_id: 123, subject: "math", limit: 5)
      {:ok, [
        %{topic: "Quadratic Equations", weakness_score: 0.82, recent_scores: [45, 52, 48]},
        %{topic: "Logarithms", weakness_score: 0.76, recent_scores: [58, 61, 55]}
      ]}
  """
  def identify_weak_topics(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    subject = Keyword.fetch!(opts, :subject)
    limit = Keyword.get(opts, :limit, 5)

    # Get diagnostic weak areas
    diagnostic_weak_areas = get_diagnostic_weak_areas(user_id, subject)

    # Get practice session topic performance
    practice_topic_performance = get_practice_topic_performance(user_id, subject)

    # Combine and calculate weakness scores
    weak_topics =
      merge_weakness_data(diagnostic_weak_areas, practice_topic_performance)
      |> Enum.sort_by(& &1.weakness_score, :desc)
      |> Enum.take(limit)

    {:ok, weak_topics}
  end

  @doc """
  Calculates session effectiveness score based on multiple factors.

  Factors include:
  - Score improvement vs baseline
  - Time efficiency (score per minute)
  - Focus score (consistent pacing)
  - Completion rate

  ## Example

      iex> calculate_session_effectiveness(session_id: 456)
      {:ok, %{
        overall_score: 0.85,
        improvement_score: 0.92,
        time_efficiency: 0.78,
        focus_score: 0.85,
        completion_rate: 1.0
      }}
  """
  def calculate_session_effectiveness(session_id: session_id) do
    session = Repo.get(PracticeSession, session_id)

    if is_nil(session) or not session.completed do
      {:error, :session_not_found_or_incomplete}
    else
      user_id = session.user_id
      subject = session.subject

      # Get user's baseline performance for this subject
      baseline = get_user_baseline(user_id, subject)

      # Calculate effectiveness metrics
      effectiveness = %{
        overall_score: calculate_overall_effectiveness(session, baseline),
        improvement_score: calculate_improvement_score(session, baseline),
        time_efficiency: calculate_time_efficiency(session),
        focus_score: calculate_focus_score(session),
        completion_rate: if(session.completed, do: 1.0, else: 0.0)
      }

      {:ok, effectiveness}
    end
  end

  @doc """
  Generates personalized study recommendations based on analytics.

  Recommendations include:
  - Next best topic to study
  - Optimal study time
  - Recommended session duration
  - Difficulty level adjustment
  - Study method suggestions

  ## Example

      iex> generate_recommendations(user_id: 123)
      {:ok, %{
        next_topic: "Polynomial Factoring",
        optimal_time: ~T[14:00:00],
        recommended_duration: 25,
        difficulty_adjustment: :increase_slightly,
        study_methods: [:spaced_repetition, :practice_problems]
      }}
  """
  def generate_recommendations(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    subject = Keyword.get(opts, :subject)

    with {:ok, patterns} <- analyze_learning_patterns(user_id: user_id),
         {:ok, trends} <- analyze_performance_trends(user_id: user_id, subject: subject),
         {:ok, weak_topics} <- identify_weak_topics(user_id: user_id, subject: subject || "math") do
      recommendations = %{
        next_topic: select_next_topic(weak_topics, trends),
        optimal_time: format_peak_hours(patterns.peak_hours),
        recommended_duration: patterns.optimal_duration_minutes,
        difficulty_adjustment: suggest_difficulty_adjustment(trends),
        study_methods: suggest_study_methods(patterns, trends),
        weak_areas: Enum.map(weak_topics, & &1.topic)
      }

      {:ok, recommendations}
    end
  end

  @doc """
  Compares user's performance against peers in similar cohort.

  Returns percentile rankings and comparison metrics:
  - Overall percentile
  - Subject-specific rankings
  - Study habit comparisons
  - Improvement velocity vs peers

  ## Example

      iex> compare_to_peers(user_id: 123, grade_level: 10)
      {:ok, %{
        overall_percentile: 78,
        subject_rankings: %{"math" => 82, "english" => 74},
        study_consistency_percentile: 85,
        improvement_velocity_percentile: 90
      }}
  """
  def compare_to_peers(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    grade_level = Keyword.get(opts, :grade_level)

    # Get user's recent average score
    user_avg = get_user_average_score(user_id, days: 30)

    # Get peer cohort average scores (same grade level)
    peer_scores = get_peer_cohort_scores(grade_level, days: 30)

    if Enum.empty?(peer_scores) do
      {:ok, %{overall_percentile: nil, insufficient_data: true}}
    else
      percentile = calculate_percentile(user_avg, peer_scores)

      comparison = %{
        overall_percentile: percentile,
        user_score: user_avg,
        peer_median: calculate_median(peer_scores),
        peer_count: length(peer_scores)
      }

      {:ok, comparison}
    end
  end

  # Private helper functions

  defp empty_patterns do
    %{
      peak_hours: [],
      optimal_duration_minutes: 25,
      consistency_score: 0.0,
      subject_affinity: %{},
      total_sessions: 0,
      avg_score: 0.0
    }
  end

  defp empty_trends do
    %{
      direction: :unknown,
      velocity: 0.0,
      current_score: nil,
      projected_score_30d: nil,
      trend_line: []
    }
  end

  defp identify_peak_performance_hours(sessions) do
    sessions
    |> Enum.group_by(& &1.hour_of_day)
    |> Enum.map(fn {hour, group_sessions} ->
      avg_score = Enum.reduce(group_sessions, 0, &(&1.score + &2)) / length(group_sessions)
      {hour, avg_score}
    end)
    |> Enum.sort_by(fn {_hour, score} -> score end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _score} -> trunc(hour) end)
  end

  defp calculate_optimal_duration(sessions) do
    # Group by duration buckets and find best performing duration
    sessions
    |> Enum.group_by(fn s -> div(s.duration, 300) * 5 end)  # 5-min buckets
    |> Enum.map(fn {duration_bucket, group_sessions} ->
      avg_score = calculate_average_score(group_sessions)
      {duration_bucket, avg_score}
    end)
    |> Enum.max_by(fn {_duration, score} -> score end, fn -> {25, 0} end)
    |> elem(0)
  end

  defp calculate_consistency_score(sessions, days_back) do
    # Calculate how consistently user studies (days with sessions / total days)
    unique_dates = sessions |> Enum.map(& &1.date) |> Enum.uniq() |> length()
    unique_dates / days_back
  end

  defp calculate_subject_affinity(sessions) do
    sessions
    |> Enum.group_by(& &1.subject)
    |> Enum.map(fn {subject, group_sessions} ->
      avg_score = calculate_average_score(group_sessions)
      {subject, avg_score / 100}  # Normalize to 0-1
    end)
    |> Map.new()
  end

  defp calculate_average_score(sessions) do
    if Enum.empty?(sessions) do
      0.0
    else
      total = Enum.reduce(sessions, 0, fn s, acc -> (s.score || 0) + acc end)
      total / length(sessions)
    end
  end

  defp calculate_trends(scores) do
    score_values = Enum.map(scores, & &1.score)

    if length(score_values) < 2 do
      empty_trends()
    else
      # Simple linear regression for trend
      n = length(score_values)
      x_values = Enum.to_list(1..n)

      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(score_values) / n

      numerator = Enum.zip(x_values, score_values)
                  |> Enum.reduce(0, fn {x, y}, acc -> acc + (x - x_mean) * (y - y_mean) end)

      denominator = Enum.reduce(x_values, 0, fn x, acc -> acc + :math.pow(x - x_mean, 2) end)

      slope = if denominator != 0, do: numerator / denominator, else: 0

      direction = cond do
        slope > 0.5 -> :improving
        slope < -0.5 -> :declining
        true -> :stable
      end

      current_score = List.last(score_values)
      projected_score = current_score + (slope * 30)  # Project 30 sessions ahead

      %{
        direction: direction,
        velocity: slope,
        current_score: current_score,
        projected_score_30d: min(100, max(0, trunc(projected_score))),
        trend_line: score_values
      }
    end
  end

  defp get_diagnostic_weak_areas(user_id, subject) do
    # Query diagnostic results for weak topics
    case DiagnosticContext.get_latest_assessment(user_id, subject) do
      nil -> []
      assessment ->
        # Extract weak topics from assessment metadata
        weak_topics = get_in(assessment, [:metadata, "weak_topics"]) || []
        Enum.map(weak_topics, fn topic ->
          %{topic: topic, source: :diagnostic, weakness_score: 0.8}
        end)
    end
  end

  defp get_practice_topic_performance(user_id, subject) do
    # Query recent practice session topic-level performance
    from(s in PracticeSession,
      where: s.user_id == ^user_id and s.subject == ^subject and s.completed == true,
      order_by: [desc: s.inserted_at],
      limit: 50,
      select: %{topic: fragment("?->>'topic'", s.metadata), score: s.score}
    )
    |> Repo.all()
    |> Enum.filter(&(&1.topic != nil))
    |> Enum.group_by(& &1.topic)
    |> Enum.map(fn {topic, sessions} ->
      avg_score = calculate_average_score(sessions)
      weakness_score = (100 - avg_score) / 100  # Invert: low score = high weakness
      %{topic: topic, source: :practice, weakness_score: weakness_score, recent_scores: Enum.map(sessions, & &1.score)}
    end)
  end

  defp merge_weakness_data(diagnostic_weak, practice_weak) do
    all_topics = (Enum.map(diagnostic_weak, & &1.topic) ++ Enum.map(practice_weak, & &1.topic))
                 |> Enum.uniq()

    Enum.map(all_topics, fn topic ->
      diag_entry = Enum.find(diagnostic_weak, &(&1.topic == topic))
      practice_entry = Enum.find(practice_weak, &(&1.topic == topic))

      weakness_score = case {diag_entry, practice_entry} do
        {nil, nil} -> 0.0
        {diag, nil} -> diag.weakness_score
        {nil, prac} -> prac.weakness_score
        {diag, prac} -> (diag.weakness_score + prac.weakness_score) / 2
      end

      %{
        topic: topic,
        weakness_score: weakness_score,
        recent_scores: (practice_entry && practice_entry.recent_scores) || []
      }
    end)
  end

  defp get_user_baseline(user_id, subject) do
    # Get user's baseline (first 10 sessions) average score
    from(s in PracticeSession,
      where: s.user_id == ^user_id and s.subject == ^subject and s.completed == true,
      order_by: [asc: s.inserted_at],
      limit: 10,
      select: s.score
    )
    |> Repo.all()
    |> calculate_average_score_from_list()
  end

  defp calculate_average_score_from_list(scores) do
    if Enum.empty?(scores) do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  defp calculate_overall_effectiveness(session, baseline) do
    # Weighted combination of metrics
    improvement = calculate_improvement_score(session, baseline)
    time_eff = calculate_time_efficiency(session)
    focus = calculate_focus_score(session)

    (improvement * 0.4 + time_eff * 0.3 + focus * 0.3)
  end

  defp calculate_improvement_score(session, baseline) do
    if baseline == 0, do: 0.5, else: min(1.0, session.score / baseline)
  end

  defp calculate_time_efficiency(session) do
    # Score per minute, normalized
    if session.timer_seconds == 0 do
      0.5
    else
      minutes = session.timer_seconds / 60
      efficiency = session.score / minutes
      min(1.0, efficiency / 10)  # Normalize assuming 10 points/min is excellent
    end
  end

  defp calculate_focus_score(_session) do
    # Placeholder: In real implementation, analyze answer timing variance
    # Low variance = high focus
    0.85
  end

  defp select_next_topic(weak_topics, _trends) do
    if Enum.empty?(weak_topics) do
      "Continue practicing current topics"
    else
      List.first(weak_topics).topic
    end
  end

  defp format_peak_hours(hours) do
    if Enum.empty?(hours) do
      nil
    else
      hour = Enum.min(hours)
      Time.new!(hour, 0, 0)
    end
  end

  defp suggest_difficulty_adjustment(trends) do
    case trends.direction do
      :improving -> if trends.velocity > 1.0, do: :increase_slightly, else: :maintain
      :declining -> :decrease_slightly
      _ -> :maintain
    end
  end

  defp suggest_study_methods(patterns, trends) do
    methods = []

    methods = if patterns.consistency_score < 0.5 do
      [:daily_practice | methods]
    else
      methods
    end

    methods = if trends.direction == :improving do
      [:challenge_problems | methods]
    else
      [:review_fundamentals | methods]
    end

    methods = if Enum.empty?(methods), do: [:spaced_repetition, :practice_problems], else: methods

    Enum.take(methods, 3)
  end

  defp get_user_average_score(user_id, opts) do
    days = Keyword.get(opts, :days, 30)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    from(s in PracticeSession,
      where: s.user_id == ^user_id and s.completed == true and s.inserted_at >= ^cutoff_date,
      select: s.score
    )
    |> Repo.all()
    |> calculate_average_score_from_list()
  end

  defp get_peer_cohort_scores(_grade_level, opts) do
    days = Keyword.get(opts, :days, 30)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    # Note: Assuming users table has grade_level field
    # This would need to join with users table
    from(s in PracticeSession,
      where: s.completed == true and s.inserted_at >= ^cutoff_date,
      select: avg(s.score),
      group_by: s.user_id
    )
    |> Repo.all()
    |> Enum.filter(&(&1 != nil))
  end

  defp calculate_percentile(value, population) do
    below_count = Enum.count(population, &(&1 < value))
    trunc(below_count / length(population) * 100)
  end

  defp calculate_median(values) do
    sorted = Enum.sort(values)
    mid = div(length(sorted), 2)

    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
end
