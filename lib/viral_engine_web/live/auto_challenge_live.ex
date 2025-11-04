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

  defp get_user_auto_challenges(_user_id) do
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

  # Note: Additional UI helper functions have been removed until a render/1 function or .heex template is implemented.
  # Functions included: challenge_motivation_text/1, calculate_days_since_best/1, share_message/1,
  # challenge_url/1, time_remaining/1, difficulty_indicator/1, progress_to_target/2
end
