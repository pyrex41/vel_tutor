defmodule ViralEngine.Loops.BuddyChallenge do
  @moduledoc """
  Buddy Challenge viral loop agent.

  Handles student-to-student challenges after practice completion.
  Creates personalized challenge decks and manages the complete viral flow.
  """

  require Logger
  alias ViralEngine.{Repo, AttributionContext, MCP, AnalyticsContext, Support.DateTimeHelpers}

  @doc """
  Generates a buddy challenge for a practice completion event.

  ## Parameters
  - event: Practice completion event with user_id and context
  - config: Loop configuration

  ## Returns
  - {:ok, share_pack} - Challenge generated successfully
  - {:error, reason} - Generation failed
  """
  def generate(event, _config) do
    user = fetch_user(event.user_id)

    # Create 5-question challenge deck
    deck =
      create_challenge_deck(
        event.context.skill || "math",
        event.context.questions_count || 5
      )

    # Generate smart link with attribution
    {:ok, link_data} =
      AttributionContext.create_attribution_link(
        user.id,
        "buddy_challenge",
        "/buddy-challenge/join",
        metadata: %{
          loop_id: :buddy_challenge,
          deck_id: deck.id,
          skill: event.context.skill,
          referrer_score: event.context.score
        }
      )

    # Get personalized content via MCP
    {:ok, personalization} =
      MCP.Client.call_agent(
        "personalization-agent",
        "personalize",
        %{
          user_id: user.id,
          loop_type: :buddy_challenge,
          context: event.context
        }
      )

    # Generate share pack
    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: personalization.cta,
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      share_card: generate_share_card(user, deck, event),
      share_copy: personalization.share_copy,
      channels: [:sms, :whatsapp, :copy_link],
      reward_preview: personalization.reward
    }

    # Log exposure
    AnalyticsContext.log(%{
      event_type: "loop_exposed",
      user_id: user.id,
      loop_type: "buddy_challenge",
      action: "exposed",
      metadata: %{
        deck_id: deck.id,
        link_code: link_data.link_token
      }
    })

    {:ok,
     %{
       action: :show_share_modal,
       share_pack: share_pack
     }}
  end

  @doc """
  Handles a user joining a buddy challenge via shared link.

  ## Parameters
  - link_code: Attribution link code
  - joiner_id: User ID of the person joining

  ## Returns
  - {:ok, join_data} - Successfully joined challenge
  - {:error, reason} - Join failed
  """
  def handle_join(link_code, joiner_id) do
    {:ok, link, _click} = AttributionContext.track_click(link_code, %{user_agent: "viral-engine", ip_address: "127.0.0.1"})

    # Load challenge deck
    deck = Repo.get!(ViralEngine.ChallengeDeck, link.context["deck_id"])

    # Create session for joiner
    session = %ViralEngine.ChallengeSession{
      deck_id: deck.id,
      user_id: joiner_id,
      referrer_id: link.referrer_id,
      link_id: link.id,
      score: nil,
      completed_at: nil
    }

    {:ok, session} = Repo.insert(session)

    # Log FVM (first value moment)
    AnalyticsContext.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      loop_type: "buddy_challenge",
      action: "joined",
      metadata: %{
        deck_id: deck.id,
        referrer_id: link.referrer_id
      }
    })

    {:ok,
     %{
       deck: deck,
       session: session,
       referrer_score: link.context["referrer_score"]
     }}
  end

  @doc """
  Completes a buddy challenge and handles reward distribution.

  ## Parameters
  - session_id: Challenge session ID
  - score: Final score achieved

  ## Returns
  - {:ok, session} - Challenge completed successfully
  """
  def complete_challenge(session_id, score) do
    session = Repo.get!(ViralEngine.ChallengeSession, session_id)

    # Update session
    session =
      session
      |> Ecto.Changeset.change(%{
        score: score,
        completed_at: DateTimeHelpers.now_for_ecto()
      })
      |> Repo.update!()

    # Check if both users should get rewards
    referrer_score = session.link.context["referrer_score"]

    # Within 10% = success
    if score >= referrer_score * 0.9 do
      # Grant rewards to both
      grant_challenge_rewards(session.referrer_id, session.user_id)
    end

    {:ok, session}
  end

  # Private functions

  defp create_challenge_deck(skill, question_count) do
    questions = fetch_questions_for_skill(skill, question_count)

    deck = %ViralEngine.ChallengeDeck{
      type: "buddy_challenge",
      skill: skill,
      questions: questions,
      participant_count: 0,
      completion_count: 0,
      # 48 hours
      expires_at: DateTime.add(DateTimeHelpers.now_for_ecto(), 48 * 3600)
    }

    Repo.insert!(deck)
  end

  defp generate_share_card(user, deck, event) do
    %{
      type: :buddy_challenge,
      image_url: generate_card_image(user, deck, event),
      title: "Can you beat my #{deck.skill} score?",
      description:
        "I scored #{event.context.score}% on #{deck.skill}. Think you can do better? 🎯",
      og_tags: %{
        "og:title" => "#{user.name}'s #{deck.skill} Challenge",
        "og:description" => "Beat my score and we both win!",
        "og:image" => generate_card_image(user, deck, event)
      }
    }
  end

  defp generate_card_image(_user, deck, event) do
    # Generate dynamic image (use Cloudinary, imgix, or similar)
    # For now, return placeholder
    "/images/challenge_cards/#{deck.skill}_#{event.context.score}.png"
  end

  defp grant_challenge_rewards(referrer_id, joiner_id) do
    # Grant to referrer
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: referrer_id,
        reward_type: "streak_shield",
        amount: 1,
        context: %{loop_id: :buddy_challenge, role: :referrer}
      }
    )

    # Grant to joiner
    MCP.Client.call_agent(
      "incentives-agent",
      "grant_reward",
      %{
        user_id: joiner_id,
        reward_type: "streak_shield",
        amount: 1,
        context: %{loop_id: :buddy_challenge, role: :joiner}
      }
    )
  end

  defp fetch_questions_for_skill(skill, count) do
    # Fetch from question bank - simplified for now
    # In production, this would query the actual question database
    Enum.map(1..count, fn i ->
      %{
        id: "q#{i}",
        question: "Sample #{skill} question #{i}?",
        answers: ["A", "B", "C", "D"],
        correct_answer: "A"
      }
    end)
  end

  defp fetch_user(user_id) do
    Repo.get!(ViralEngine.Accounts.User, user_id)
  end
end
