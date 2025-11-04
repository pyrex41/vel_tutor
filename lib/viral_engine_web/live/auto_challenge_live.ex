defmodule ViralEngineWeb.AutoChallengeLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ChallengeContext, PracticeContext}
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to auto-challenge events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:challenges")
    end

    # Get user's active auto-challenges
    auto_challenges = get_user_auto_challenges(user.id)

    # Get user's recent stats for motivation
    stats = PracticeContext.get_user_stats(user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:auto_challenges, auto_challenges)
      |> assign(:stats, stats)
      |> assign(:selected_challenge, nil)
      |> assign(:show_share_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("accept_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)

    # Redirect to practice session for this challenge
    challenge = Enum.find(socket.assigns.auto_challenges, & &1.id == challenge_id)

    if challenge do
      # Create practice session for this challenge
      {:ok, session} = PracticeContext.create_session(%{
        user_id: socket.assigns.user_id,
        session_type: "practice_test",
        subject: challenge.subject,
        grade_level: challenge.grade_level,
        metadata: %{
          challenge_id: challenge.id,
          target_score: challenge.target_score
        }
      })

      {:noreply,
       socket
       |> put_flash(:info, "Challenge accepted! Beat your score of #{challenge.target_score}!")
       |> redirect(to: "/practice/#{session.id}")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Challenge not found")}
    end
  end

  @impl true
  def handle_event("share_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)
    challenge = Enum.find(socket.assigns.auto_challenges, & &1.id == challenge_id)

    if challenge do
      {:noreply,
       socket
       |> assign(:selected_challenge, challenge)
       |> assign(:show_share_modal, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:selected_challenge, nil)}
  end

  @impl true
  def handle_event("copy_challenge_link", %{"token" => token}, socket) do
    # Would copy to clipboard in frontend
    challenge_url = "#{ViralEngineWeb.Endpoint.url()}/challenge/#{token}"

    Logger.info("Challenge link copied: #{challenge_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Challenge link copied to clipboard!")}
  end

  @impl true
  def handle_event("dismiss_challenge", %{"challenge_id" => challenge_id_str}, socket) do
    challenge_id = String.to_integer(challenge_id_str)

    # Mark challenge as dismissed (update status to cancelled)
    case ChallengeContext.cancel_challenge(challenge_id) do
      {:ok, _challenge} ->
        # Remove from list
        updated_challenges = Enum.reject(socket.assigns.auto_challenges, & &1.id == challenge_id)

        {:noreply,
         socket
         |> assign(:auto_challenges, updated_challenges)
         |> put_flash(:info, "Challenge dismissed")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to dismiss challenge")}
    end
  end

  @impl true
  def handle_info({:challenge_created, %{challenge: challenge}}, socket) do
    # Add new auto-challenge to list if it's auto-generated
    if challenge.metadata["auto_generated"] do
      updated_challenges = [challenge | socket.assigns.auto_challenges]

      {:noreply,
       socket
       |> assign(:auto_challenges, updated_challenges)
       |> put_flash(:info, "🎯 New challenge available! Can you beat your best score?")}
    else
      {:noreply, socket}
    end
  end

  # Helper functions

  defp get_user_auto_challenges(user_id) do
    # Get all pending self-challenges that are auto-generated
    # In production:
    # from(c in Challenge,
    #   where: c.challenger_id == ^user_id and
    #          c.target_user_id == ^user_id and
    #          c.status == "pending" and
    #          fragment("?->>'auto_generated' = 'true'", c.metadata),
    #   order_by: [desc: c.inserted_at]
    # )
    # |> Repo.all()

    # Simulated: Return empty list
    []
  end

  defp challenge_motivation_text(challenge) do
    days_since = calculate_days_since_best(challenge)

    cond do
      days_since >= 7 ->
        "It's been #{days_since} days since your best score! Ready to prove you've still got it?"

      days_since >= 3 ->
        "#{days_since} days without practice... Time to show what you remember!"

      true ->
        "Can you beat your personal record?"
    end
  end

  defp calculate_days_since_best(challenge) do
    # Calculate days since the original session
    # In production, this would query the session timestamp
    challenge.metadata["gap_days"] || 3
  end

  defp share_message(challenge) do
    "I'm challenging myself to beat my best score of #{challenge.target_score} in #{challenge.subject}! Think you can do better? #{challenge_url(challenge)}"
  end

  defp challenge_url(challenge) do
    "#{ViralEngineWeb.Endpoint.url()}/challenge/#{challenge.challenge_token}"
  end

  defp time_remaining(expires_at) when not is_nil(expires_at) do
    seconds = DateTime.diff(expires_at, DateTime.utc_now())
    days = div(seconds, 24 * 60 * 60)

    cond do
      days > 1 -> "#{days} days left"
      days == 1 -> "1 day left"
      seconds > 3600 -> "#{div(seconds, 3600)} hours left"
      seconds > 60 -> "#{div(seconds, 60)} minutes left"
      seconds > 0 -> "Less than a minute left"
      true -> "Expired"
    end
  end

  defp time_remaining(_), do: "No expiration"

  defp difficulty_indicator(target_score) do
    cond do
      target_score >= 90 -> {"🔥", "Legendary", "text-red-600"}
      target_score >= 75 -> {"⭐", "Hard", "text-orange-600"}
      target_score >= 60 -> {"💪", "Medium", "text-yellow-600"}
      true -> {"✨", "Easy", "text-green-600"}
    end
  end

  defp progress_to_target(current_best, target) do
    if current_best >= target do
      100
    else
      round((current_best / target) * 100)
    end
  end
end
