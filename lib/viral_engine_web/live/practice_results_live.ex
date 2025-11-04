defmodule ViralEngineWeb.PracticeResultsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.PracticeContext
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

    share_url = generate_share_url(session.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:session, session)
      |> assign(:breakdown, breakdown)
      |> assign(:leaderboard, leaderboard)
      |> assign(:share_url, share_url)
      |> assign(:show_share_modal, false)

    {:ok, socket}
  end

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

    challenge_url = "#{socket.assigns.share_url}?challenge=#{session.id}&subject=#{session.subject}"

    {:noreply,
     socket
     |> assign(:share_url, challenge_url)
     |> assign(:show_share_modal, true)
     |> put_flash(:info, "Challenge created! Share the link with a friend.")}
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

  defp find_user_rank(entries, user_id) do
    entry = Enum.find(entries, fn e -> e.is_current_user end)
    entry && entry.rank
  end

  defp generate_share_url(session_id) do
    "https://veltutor.com/practice/results/#{session_id}"
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  defp get_score_color(score) when score >= 90, do: "text-green-600"
  defp get_score_color(score) when score >= 70, do: "text-yellow-600"
  defp get_score_color(_score), do: "text-red-600"

  defp get_score_message(score) when score == 100, do: "Perfect score! 🎉"
  defp get_score_message(score) when score >= 90, do: "Excellent work! 🌟"
  defp get_score_message(score) when score >= 70, do: "Great job! 👍"
  defp get_score_message(score) when score >= 50, do: "Good effort! Keep practicing! 💪"
  defp get_score_message(_score), do: "Keep trying! You'll get better! 🚀"
end
