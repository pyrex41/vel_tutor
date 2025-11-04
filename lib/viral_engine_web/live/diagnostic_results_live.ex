defmodule ViralEngineWeb.DiagnosticResultsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{DiagnosticContext, RallyContext, ViralPrompts}
  require Logger

  on_mount ViralEngineWeb.Live.ViralPromptsHook

  @impl true
  def mount(%{"id" => assessment_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    case DiagnosticContext.get_user_assessment(assessment_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Assessment not found")
         |> redirect(to: "/dashboard")}

      assessment ->
        if assessment.completed do
          initialize_results(socket, user, assessment)
        else
          {:ok,
           socket
           |> put_flash(:warning, "Assessment not yet completed")
           |> redirect(to: "/diagnostic/#{assessment_id}")}
        end
    end
  end

  defp initialize_results(socket, user, assessment) do
    results = assessment.results
    recommendations = generate_ai_recommendations(assessment)
    share_url = generate_share_url(assessment.id)

    # Trigger viral prompt for results rally
    viral_prompt = trigger_results_rally_prompt(user.id, assessment)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:assessment, assessment)
      |> assign(:results, results)
      |> assign(:recommendations, recommendations)
      |> assign(:share_url, share_url)
      |> assign(:show_share_modal, false)
      |> assign(:viral_prompt, viral_prompt)
      |> assign(:show_viral_modal, viral_prompt != nil)
      |> assign(:rally_created, false)
      |> assign(:rally_link, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, !socket.assigns.show_share_modal)}
  end

  @impl true
  def handle_event("challenge_friend", _params, socket) do
    assessment = socket.assigns.assessment

    # Generate challenge link
    challenge_url = "#{socket.assigns.share_url}?challenge=#{assessment.id}"

    {:noreply,
     socket
     |> assign(:share_url, challenge_url)
     |> assign(:show_share_modal, true)
     |> put_flash(:info, "Challenge link generated! Share with a friend.")}
  end

  @impl true
  def handle_event("study_together", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Study together feature coming soon!")
     |> redirect(to: "/dashboard")}
  end

  @impl true
  def handle_event("retake_assessment", _params, socket) do
    assessment = socket.assigns.assessment

    # Create new assessment with same parameters
    {:ok, new_assessment} =
      DiagnosticContext.create_assessment(%{
        user_id: socket.assigns.user.id,
        subject: assessment.subject,
        grade_level: assessment.grade_level
      })

    {:noreply, redirect(socket, to: "/diagnostic/#{new_assessment.id}")}
  end

  @impl true
  def handle_event("share_native", _params, socket) do
    # Use Web Share API (handled in JavaScript hook)
    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_share_link", _params, socket) do
    # Copy to clipboard (handled in JavaScript)
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  # Private functions

  defp generate_ai_recommendations(assessment) do
    results = assessment.results
    skill_heatmap = results["skill_heatmap"] || %{}

    # Find weak skills (< 70%)
    weak_skills =
      skill_heatmap
      |> Enum.filter(fn {_skill, score} -> score < 70 end)
      |> Enum.sort_by(fn {_skill, score} -> score end)
      |> Enum.take(3)

    # Find strong skills (>= 80%)
    strong_skills =
      skill_heatmap
      |> Enum.filter(fn {_skill, score} -> score >= 80 end)
      |> Enum.sort_by(fn {_skill, score} -> -score end)
      |> Enum.take(3)

    recommendations = []

    # Add recommendations for weak skills
    recommendations =
      if length(weak_skills) > 0 do
        weak_skill_names = Enum.map(weak_skills, fn {skill, _} -> skill end) |> Enum.join(", ")

        [
          "Focus on #{weak_skill_names} - these areas need more practice",
          "Try daily 10-minute drills to improve #{Enum.at(weak_skills, 0) |> elem(0)}",
          "Watch tutorial videos on #{weak_skill_names} concepts"
          | recommendations
        ]
      else
        recommendations
      end

    # Add recommendations for strong skills
    recommendations =
      if length(strong_skills) > 0 do
        strong_skill_names = Enum.map(strong_skills, fn {skill, _} -> skill end) |> Enum.join(", ")

        [
          "Great job on #{strong_skill_names}! Keep up the excellent work",
          "Challenge yourself with advanced #{Enum.at(strong_skills, 0) |> elem(0)} problems"
          | recommendations
        ]
      else
        recommendations
      end

    # Add general recommendations
    accuracy = results["accuracy"] || 0

    recommendations =
      cond do
        accuracy >= 90 ->
          ["You're performing excellently! Consider taking advanced practice tests" | recommendations]

        accuracy >= 70 ->
          ["Solid performance! Keep practicing to reach expert level" | recommendations]

        accuracy >= 50 ->
          ["Good start! Focus on fundamentals and practice regularly" | recommendations]

        true ->
          ["Don't worry! Everyone starts somewhere. Practice daily and you'll improve" | recommendations]
      end

    recommendations
  end

  defp generate_share_url(assessment_id) do
    # In production, this would generate a proper shareable URL
    "https://veltutor.com/diagnostic/results/#{assessment_id}"
  end

  defp get_skill_color(score) when score >= 80, do: "bg-green-500"
  defp get_skill_color(score) when score >= 60, do: "bg-yellow-500"
  defp get_skill_color(_score), do: "bg-red-500"

  defp get_percentile_message(percentile) when percentile >= 90,
    do: "Outstanding! You're in the top 10%"

  defp get_percentile_message(percentile) when percentile >= 75,
    do: "Great job! You're performing better than most students"

  defp get_percentile_message(percentile) when percentile >= 50,
    do: "Good work! You're right around average"

  defp get_percentile_message(_percentile), do: "Keep practicing - you can improve!"

  @impl true
  def handle_event("create_rally", _params, socket) do
    assessment = socket.assigns.assessment
    user = socket.assigns.user

    case RallyContext.create_rally(user.id, assessment.id) do
      {:ok, rally} ->
        rally_link = RallyContext.generate_rally_link(rally)

        {:noreply,
         socket
         |> assign(:rally_created, true)
         |> assign(:rally_link, rally_link)
         |> assign(:show_viral_modal, false)
         |> put_flash(:success, "Rally created! Share the link to invite friends.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not create rally. Please try again.")}
    end
  end

  @impl true
  def handle_event("close_viral_modal", _params, socket) do
    {:noreply, assign(socket, :show_viral_modal, false)}
  end

  @impl true
  def handle_event("viral_prompt_clicked", %{"prompt_log_id" => log_id}, socket) do
    # Record click
    if log_id do
      ViralPrompts.record_click(String.to_integer(log_id))
    end

    # Close modal
    {:noreply, assign(socket, :show_viral_modal, false)}
  end

  defp trigger_results_rally_prompt(user_id, assessment) do
    event_data = %{
      assessment_id: assessment.id,
      score: assessment.results["overall_score"] || 0,
      subject: assessment.subject,
      grade_level: assessment.grade_level
    }

    case ViralPrompts.trigger_prompt(:diagnostic_completed, user_id, event_data) do
      {:ok, prompt} ->
        # Broadcast event for analytics
        ViralPrompts.broadcast_event(:diagnostic_completed, user_id, event_data)
        prompt

      {:throttled, reason} ->
        Logger.info("Viral prompt throttled for user #{user_id}: #{reason}")
        nil

      {:no_prompt, reason} ->
        Logger.info("No viral prompt for user #{user_id}: #{reason}")
        # Fallback to default prompt
        ViralPrompts.get_default_prompt(:diagnostic_completed)
    end
  end
end
