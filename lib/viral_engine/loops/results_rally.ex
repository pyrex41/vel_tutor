defmodule ViralEngine.Loops.ResultsRally do
  @moduledoc """
  Results Rally viral loop agent.

  Handles async-to-social sharing of diagnostic results with leaderboards.
  Shows cohort rankings and encourages social sharing.
  """

  require Logger
  alias ViralEngine.{Repo, AttributionContext, MCP, AnalyticsContext}

  @doc """
  Generates a results rally for a diagnostic completion event.

  ## Parameters
  - event: Diagnostic completion event with user_id and context
  - config: Loop configuration

  ## Returns
  - {:ok, rally_data} - Rally generated successfully
  - {:error, reason} - Generation failed
  """
  def generate(event, _config) do
    user = fetch_user(event.user_id)
    results = event.context.results

    # Get cohort leaderboard
    leaderboard =
      fetch_cohort_leaderboard(
        user.cohort_id || 1,
        results.subject,
        limit: 25
      )

    # Calculate user rank
    user_rank = calculate_rank(user.id, leaderboard)

    # Generate smart link with attribution
    {:ok, link_data} =
      AttributionContext.create_attribution_link(
        user.id,
        "results_rally",
        "/results-rally/join",
        metadata: %{
          loop_id: :results_rally,
          subject: results.subject,
          cohort_id: user.cohort_id,
          referrer_rank: user_rank
        }
      )

    # Get personalized content
    {:ok, personalization} =
      MCP.Client.call_agent(
        "personalization-agent",
        "personalize",
        %{
          user_id: user.id,
          loop_type: :results_rally,
          context:
            Map.merge(event.context, %{rank: user_rank, leaderboard_size: length(leaderboard)})
        }
      )

    # Build share pack
    share_pack = %{
      headline: personalization.headline,
      body: personalization.body,
      cta: personalization.cta,
      share_link: link_data.url,
      deep_link: link_data.deep_link,
      share_card: generate_leaderboard_card(user, leaderboard, results, user_rank),
      share_copy: personalization.share_copy,
      leaderboard_widget: render_leaderboard_widget(leaderboard, user.id),
      channels: [:copy_link, :sms, :twitter, :instagram_story],
      reward_preview: personalization.reward
    }

    # Log exposure
    AnalyticsContext.log(%{
      event_type: "loop_exposed",
      user_id: user.id,
      loop_type: "results_rally",
      action: "exposed",
      metadata: %{
        rank: user_rank,
        link_code: link_data.link_token
      }
    })

    {:ok,
     %{
       action: :show_results_with_social,
       share_pack: share_pack,
       leaderboard: leaderboard,
       user_rank: user_rank
     }}
  end

  @doc """
  Handles a user joining a results rally via shared link.

  ## Parameters
  - link_code: Attribution link code
  - joiner_id: User ID of the person joining

  ## Returns
  - {:ok, join_data} - Successfully joined rally
  - {:error, reason} - Join failed
  """
  def handle_join(link_code, joiner_id) do
    {:ok, link, _click} = AttributionContext.track_click(link_code, %{user_agent: "viral-engine", ip_address: "127.0.0.1"})

    # Get cohort and subject from link
    cohort_id = link.context["cohort_id"]
    subject = link.context["subject"]

    # Show joiner the leaderboard
    leaderboard = fetch_cohort_leaderboard(cohort_id, subject)

    # Prompt to take diagnostic
    diagnostic = find_matching_diagnostic(subject)

    # Log FVM
    AnalyticsContext.log(%{
      event_type: "fvm_reached",
      user_id: joiner_id,
      loop_type: "results_rally",
      action: "joined",
      metadata: %{
        subject: subject,
        referrer_id: link.referrer_id
      }
    })

    {:ok,
     %{
       leaderboard: leaderboard,
       diagnostic: diagnostic,
       subject: subject,
       referrer_rank: link.context["referrer_rank"]
     }}
  end

  # Private functions

  defp fetch_cohort_leaderboard(_cohort_id, _subject, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Get active presence (simplified - would check actual presence in production)
    # Mock active users
    active_user_ids = [1, 2, 3]

    # Mock leaderboard data - in production would query actual results
    Enum.map(1..min(limit, 10), fn rank ->
      %{
        user_id: rank * 100,
        name: "Student #{rank}",
        score: 100 - rank * 5,
        completed_at: DateTime.utc_now(),
        is_online: rank in active_user_ids,
        rank: rank
      }
    end)
  end

  defp calculate_rank(user_id, leaderboard) do
    case Enum.find(leaderboard, fn entry -> entry.user_id == user_id end) do
      nil -> nil
      entry -> entry.rank
    end
  end

  defp generate_leaderboard_card(user, leaderboard, results, rank) do
    %{
      type: :results_rally,
      image_url: generate_leaderboard_image(leaderboard, rank),
      title: "Ranked ##{rank} in #{results.subject}!",
      description: "I scored #{results.score}% on #{results.subject}. Can you beat it?",
      og_tags: %{
        "og:title" => "#{user.name} is ##{rank} in #{results.subject}",
        "og:description" => "Join the leaderboard and compete!",
        "og:image" => generate_leaderboard_image(leaderboard, rank)
      }
    }
  end

  defp render_leaderboard_widget(leaderboard, current_user_id) do
    # Return HTML/component data for embedding
    %{
      type: :leaderboard,
      # Top 10
      entries: Enum.take(leaderboard, 10),
      current_user_id: current_user_id,
      live_updates: true
    }
  end

  defp generate_leaderboard_image(_leaderboard, rank) do
    # Generate dynamic image showing top 5 + current user
    "/images/leaderboard_cards/rank_#{rank}.png"
  end

  defp find_matching_diagnostic(subject) do
    # Mock diagnostic - in production would query actual diagnostics
    %{
      id: 123,
      subject: subject,
      title: "#{String.capitalize(subject)} Diagnostic Test",
      questions_count: 20
    }
  end

  defp fetch_user(user_id) do
    Repo.get!(ViralEngine.Accounts.User, user_id)
  end
end
