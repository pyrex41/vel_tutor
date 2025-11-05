defmodule ViralEngineWeb.ChallengeLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{ChallengeContext, PracticeContext}
  require Logger

  @impl true
  def mount(%{"token" => token}, session, socket) do
    user = get_current_user(session)

    case ChallengeContext.get_challenge_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:stage, :error)
         |> assign(:error_message, "Challenge not found")
         |> assign(:challenge, nil)}

      challenge ->
        if user do
          handle_authenticated_challenge(socket, challenge, user)
        else
          handle_unauthenticated_challenge(socket, challenge, token)
        end
    end
  end

  defp handle_authenticated_challenge(socket, challenge, user) do
    cond do
      challenge.challenger_id == user.id ->
        # Viewing own challenge
        socket =
          socket
          |> assign(:stage, :own_challenge)
          |> assign(:challenge, challenge)
          |> assign(:user, user)
          |> assign(:share_link, ChallengeContext.generate_challenge_link(challenge))

        {:ok, socket}

      challenge.status == "pending" ->
        # Can accept the challenge
        socket =
          socket
          |> assign(:stage, :accept)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}

      challenge.status == "accepted" && challenge.challenged_user_id == user.id ->
        # User accepted, needs to complete challenge
        socket =
          socket
          |> assign(:stage, :in_progress)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}

      challenge.status == "completed" ->
        # Show results
        socket =
          socket
          |> assign(:stage, :results)
          |> assign(:challenge, challenge)
          |> assign(:user, user)
          |> assign(:is_winner, challenge.winner_id == user.id)

        {:ok, socket}

      true ->
        socket =
          socket
          |> assign(:stage, :expired)
          |> assign(:challenge, challenge)
          |> assign(:user, user)

        {:ok, socket}
    end
  end

  defp handle_unauthenticated_challenge(socket, challenge, token) do
    # Store challenge token in session, redirect to login
    socket =
      socket
      |> assign(:stage, :login_required)
      |> assign(:challenge, challenge)
      |> assign(:challenge_token, token)

    {:ok, socket}
  end

  @impl true
  def handle_event("accept_challenge", _params, socket) do
    challenge = socket.assigns.challenge
    user = socket.assigns.user

    case ChallengeContext.accept_challenge(challenge.challenge_token, user.id) do
      {:ok, updated_challenge} ->
        {:noreply,
         socket
         |> assign(:challenge, updated_challenge)
         |> assign(:stage, :in_progress)
         |> put_flash(:success, "Challenge accepted! Start practicing to beat the score.")}

      {:error, :expired} ->
        {:noreply,
         socket
         |> assign(:stage, :expired)
         |> put_flash(:error, "This challenge has expired.")}

      {:error, :self_challenge} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can't accept your own challenge!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not accept challenge: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    challenge = socket.assigns.challenge

    # Create a new practice session with the same subject
    {:ok, session} =
      PracticeContext.create_session(%{
        user_id: socket.assigns.user.id,
        session_type: "buddy_challenge",
        subject: challenge.subject,
        total_steps: 5,
        metadata: %{challenge_id: challenge.id}
      })

    # Redirect to practice session
    {:noreply, redirect(socket, to: "/practice/#{session.id}")}
  end

  @impl true
  def handle_event("decline_challenge", _params, socket) do
    challenge = socket.assigns.challenge

    ChallengeContext.update_challenge(challenge, %{status: "declined"})

    {:noreply,
     socket
     |> assign(:stage, :declined)
     |> put_flash(:info, "Challenge declined.")}
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    # Link copied via client-side JavaScript
    {:noreply, put_flash(socket, :success, "Challenge link copied to clipboard!")}
  end

  @impl true
  def handle_event("share_challenge", %{"method" => method}, socket) do
    challenge = socket.assigns.challenge

    # Update share method
    ChallengeContext.update_challenge(challenge, %{share_method: method})

    # Log analytics
    Logger.info("Challenge #{challenge.id} shared via #{method}")

    {:noreply, put_flash(socket, :success, "Challenge shared!")}
  end

  defp get_current_user(%{"user_token" => user_token}) do
    ViralEngine.Accounts.get_user_by_session_token(user_token)
  end

  defp get_current_user(_), do: nil

  # View rendering helpers
end
