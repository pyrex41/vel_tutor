defmodule ViralEngine.ChallengeContextTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.{ChallengeContext, PracticeContext, BuddyChallenge}

  setup do
    # Create test users
    {:ok, user1} = create_test_user(1)
    {:ok, user2} = create_test_user(2)

    # Create completed practice session for user1
    {:ok, session} =
      PracticeContext.create_session(%{
        user_id: user1.id,
        session_type: "practice_test",
        subject: "math",
        total_steps: 5,
        completed: true,
        score: 85
      })

    {:ok, user1: user1, user2: user2, session: session}
  end

  describe "create_challenge/3" do
    test "creates a buddy challenge with valid session", %{user1: user1, session: session} do
      assert {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)

      assert challenge.challenger_id == user1.id
      assert challenge.session_id == session.id
      assert challenge.subject == "math"
      assert challenge.challenger_score == 85
      assert challenge.status == "pending"
      assert is_binary(challenge.challenge_token)
      assert challenge.expires_at != nil
    end

    test "includes optional parameters", %{user1: user1, user2: user2, session: session} do
      opts = [
        challenged_user_id: user2.id,
        challenged_email: "user2@test.com",
        share_method: "email"
      ]

      assert {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id, opts)

      assert challenge.challenged_user_id == user2.id
      assert challenge.challenged_email == "user2@test.com"
      assert challenge.share_method == "email"
    end

    test "returns error for invalid session", %{user1: user1} do
      assert {:error, :invalid_session} = ChallengeContext.create_challenge(user1.id, 99999)
    end
  end

  describe "accept_challenge/2" do
    setup %{user1: user1, user2: user2, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)
      {:ok, challenge: challenge}
    end

    test "allows user to accept pending challenge", %{user2: user2, challenge: challenge} do
      assert {:ok, accepted} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)

      assert accepted.challenged_user_id == user2.id
      assert accepted.status == "accepted"
      assert accepted.accepted_at != nil
    end

    test "prevents self-acceptance", %{user1: user1, challenge: challenge} do
      assert {:error, :self_challenge} = ChallengeContext.accept_challenge(challenge.challenge_token, user1.id)
    end

    test "prevents accepting already accepted challenge", %{user2: user2, challenge: challenge} do
      {:ok, _} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)

      # Try to accept again
      assert {:error, :already_accepted} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)
    end

    test "returns error for expired challenge", %{user2: user2, challenge: challenge} do
      # Manually expire the challenge
      ChallengeContext.update_challenge(challenge, %{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
      })

      assert {:error, :expired} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)
    end

    test "returns error for non-existent challenge", %{user2: user2} do
      assert {:error, :not_found} = ChallengeContext.accept_challenge("invalid_token", user2.id)
    end
  end

  describe "complete_challenge/2" do
    setup %{user1: user1, user2: user2, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)
      {:ok, _} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)
      challenge = ChallengeContext.get_challenge(challenge.id)

      # Create session for challenged user
      {:ok, challenged_session} =
        PracticeContext.create_session(%{
          user_id: user2.id,
          session_type: "buddy_challenge",
          subject: "math",
          total_steps: 5,
          completed: true,
          score: 90,  # Beat the challenger's score of 85
          metadata: %{challenge_id: challenge.id}
        })

      {:ok, challenge: challenge, challenged_session: challenged_session}
    end

    test "completes challenge and determines winner", %{challenge: challenge, challenged_session: session} do
      assert {:ok, completed} = ChallengeContext.complete_challenge(challenge.id, session.id)

      assert completed.status == "completed"
      assert completed.challenged_score == 90
      assert completed.winner_id == session.user_id  # User2 won with higher score
      assert completed.completed_at != nil
    end

    test "grants rewards on completion", %{challenge: challenge, challenged_session: session} do
      {:ok, completed} = ChallengeContext.complete_challenge(challenge.id, session.id)

      # Give task time to complete (async reward granting)
      Process.sleep(100)

      refreshed = ChallengeContext.get_challenge(completed.id)
      assert refreshed.reward_granted == true
    end
  end

  describe "list_user_challenges/2" do
    setup %{user1: user1, user2: user2, session: session} do
      # Create multiple challenges
      {:ok, challenge1} = ChallengeContext.create_challenge(user1.id, session.id)
      {:ok, challenge2} = ChallengeContext.create_challenge(user1.id, session.id)

      {:ok, challenge1: challenge1, challenge2: challenge2}
    end

    test "lists challenges for challenger", %{user1: user1, challenge1: c1, challenge2: c2} do
      challenges = ChallengeContext.list_user_challenges(user1.id)

      challenge_ids = Enum.map(challenges, & &1.id)
      assert c1.id in challenge_ids
      assert c2.id in challenge_ids
    end

    test "lists challenges for challenged user", %{user2: user2, challenge1: challenge} do
      {:ok, _} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)

      challenges = ChallengeContext.list_user_challenges(user2.id)

      assert length(challenges) > 0
      assert Enum.any?(challenges, fn c -> c.id == challenge.id end)
    end

    test "filters by status", %{user1: user1} do
      challenges = ChallengeContext.list_user_challenges(user1.id, status: "pending")

      assert Enum.all?(challenges, fn c -> c.status == "pending" end)
    end
  end

  describe "get_user_challenge_stats/1" do
    setup %{user1: user1, user2: user2, session: session} do
      # Create and complete a challenge where user1 wins
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)
      {:ok, _} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)

      {:ok, challenged_session} =
        PracticeContext.create_session(%{
          user_id: user2.id,
          session_type: "buddy_challenge",
          subject: "math",
          total_steps: 5,
          completed: true,
          score: 70,  # Lower than challenger's 85
          metadata: %{challenge_id: challenge.id}
        })

      {:ok, _} = ChallengeContext.complete_challenge(challenge.id, challenged_session.id)

      :ok
    end

    test "calculates stats for user", %{user1: user1} do
      stats = ChallengeContext.get_user_challenge_stats(user1.id)

      assert stats.total_challenges >= 1
      assert stats.completed_challenges >= 1
      assert stats.challenges_won >= 1
      assert stats.challenges_created >= 1
      assert stats.win_rate > 0.0
    end

    test "returns zero stats for user with no challenges" do
      stats = ChallengeContext.get_user_challenge_stats(9999)

      assert stats.total_challenges == 0
      assert stats.completed_challenges == 0
      assert stats.challenges_won == 0
      assert stats.win_rate == 0.0
    end
  end

  describe "generate_challenge_link/1" do
    test "generates deep link URL", %{user1: user1, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)

      link = ChallengeContext.generate_challenge_link(challenge)

      assert String.contains?(link, "/challenge/")
      assert String.contains?(link, challenge.challenge_token)
    end
  end

  describe "generate_share_message/1" do
    test "generates shareable message", %{user1: user1, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)

      message = ChallengeContext.generate_share_message(challenge)

      assert String.contains?(message, "#{challenge.challenger_score}%")
      assert String.contains?(message, challenge.subject)
      assert String.contains?(message, challenge.challenge_token)
    end
  end

  describe "expire_old_challenges/0" do
    test "expires pending challenges past expiration", %{user1: user1, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)

      # Set expiry in the past
      ChallengeContext.update_challenge(challenge, %{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
      })

      # Run expiry cleanup
      ChallengeContext.expire_old_challenges()

      # Check status
      expired = ChallengeContext.get_challenge(challenge.id)
      assert expired.status == "expired"
    end

    test "does not expire non-pending challenges", %{user1: user1, user2: user2, session: session} do
      {:ok, challenge} = ChallengeContext.create_challenge(user1.id, session.id)
      {:ok, accepted} = ChallengeContext.accept_challenge(challenge.challenge_token, user2.id)

      # Set expiry in the past
      ChallengeContext.update_challenge(accepted, %{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
      })

      # Run expiry cleanup
      ChallengeContext.expire_old_challenges()

      # Should still be accepted, not expired
      refreshed = ChallengeContext.get_challenge(accepted.id)
      assert refreshed.status == "accepted"
    end
  end

  # Helper functions

  defp create_test_user(id) do
    {:ok,
     %{
       id: id,
       email: "user#{id}@test.com",
       name: "Test User #{id}"
     }}
  end
end
