defmodule ViralEngine.Agents.Personalization do
  @moduledoc """
  Personalization Agent - Generates dynamic, personalized content using AI.

  This GenServer handles content personalization for viral loops, creating tailored
  headlines, bodies, CTAs, and share copy based on user profiles and context.
  Uses the unified AIClient for intelligent multi-provider routing (OpenAI/Groq).
  Includes fallback logic for API failures.
  """

  use GenServer
  require Logger

  alias ViralEngine.AIClient
  alias ViralEngine.Repo

  # Client API

  @doc """
  Starts the Personalization Agent GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Personalizes content for a viral loop.

  ## Parameters
  - request: Map containing user_id, loop_type, and context

  ## Returns
  - {:ok, personalized_content} - Successfully personalized content
  - {:error, reason} - Personalization failed
  """
  def personalize(request) do
    GenServer.call(__MODULE__, {:personalize, request}, 15_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      copy_templates: load_copy_templates(),
      persona_profiles: %{}
    }

    Logger.info("Personalization Agent started")
    {:ok, state}
  end

  @impl true
  def handle_call({:personalize, request}, _from, state) do
    %{
      user_id: user_id,
      loop_type: loop_type,
      context: context
    } = request

    profile = fetch_or_build_profile(user_id, state)

    personalized = %{
      headline: personalize_headline(loop_type, profile, context, state),
      body: personalize_body(loop_type, profile, context, state),
      cta: personalize_cta(loop_type, profile, context),
      share_copy: generate_share_copy(loop_type, profile, context, state),
      reward: select_reward(profile, context)
    }

    log_personalization(user_id, loop_type, personalized)

    {:reply, {:ok, personalized}, state}
  end

  # Core Logic

  defp personalize_headline(loop_type, profile, context, state) do
    template = get_template(loop_type, profile.persona, state)

    template.headline
    |> String.replace("{{name}}", profile.first_name)
    |> String.replace("{{subject}}", context[:subject] || "this")
    |> String.replace("{{score}}", to_string(context[:score] || ""))
  end

  defp personalize_body(loop_type, profile, context, state) do
    template = get_template(loop_type, profile.persona, state)

    template.body
    |> String.replace("{{name}}", profile.first_name)
    |> String.replace("{{achievement}}", context[:achievement] || "great work")
    |> String.replace("{{next_step}}", suggest_next_step(context, profile))
  end

  defp personalize_cta(loop_type, profile, _context) do
    case {loop_type, profile.persona} do
      {:buddy_challenge, :student} -> "Challenge a Friend"
      {:results_rally, :student} -> "Join the Leaderboard"
      {:buddy_challenge, :parent} -> "Have Your Child Challenge Friends"
      {:results_rally, :parent} -> "See Class Rankings"
      _ -> "Share Your Progress"
    end
  end

  defp generate_share_copy(loop_type, profile, context, state) do
    # Try Claude first, fallback to templates
    case generate_with_claude(loop_type, profile, context, state) do
      {:ok, copy} -> copy
      {:error, _} -> fallback_share_copy(loop_type, profile, context)
    end
  end

  defp generate_with_claude(loop_type, profile, context, _state) do
    prompt = build_claude_prompt(loop_type, profile, context)

    # Use AIClient with intelligent routing - general task type
    case AIClient.chat(prompt, task_type: :general, max_tokens: 150, temperature: 0.7) do
      {:ok, response} ->
        {:ok, String.trim(response.content)}

      {:error, reason} ->
        Logger.warning("AI generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_claude_prompt(loop_type, profile, context) do
    """
    Generate shareable social copy for a #{profile.persona} (#{profile.communication_style || "friendly"} tone).

    Context:
    - Loop type: #{loop_type}
    - Subject: #{context[:subject]}
    - Achievement: #{context[:achievement] || "completed practice"}
    - Score: #{context[:score]}%

    Requirements:
    - 1-2 sentences max
    - Authentic and conversational, not salesy
    - Include subtle CTA to try the platform
    - Use emojis sparingly (0-1 max)

    Output only the social copy, nothing else.
    """
  end

  defp fallback_share_copy(loop_type, profile, context) do
    case {loop_type, profile.persona} do
      {:buddy_challenge, :student} ->
        "I just aced #{context[:subject]}! 💪 Can you beat my score? Try this challenge!"

      {:results_rally, :student} ->
        "Ranked ##{context[:rank]} in #{context[:subject]}! 🎯 Join the leaderboard and see where you stand!"

      _ ->
        "Check out my progress on Varsity Tutors!"
    end
  end

  defp select_reward(profile, context) do
    case profile.persona do
      :student ->
        if context[:high_engagement] do
          %{type: :ai_tutor_minutes, amount: 30, label: "30 min AI Tutor"}
        else
          %{type: :streak_shield, amount: 1, label: "Streak Shield"}
        end

      :parent ->
        %{type: :class_pass, amount: 1, label: "Free Live Class"}

      :tutor ->
        %{type: :referral_xp, amount: 50, label: "50 Referral XP"}
    end
  end

  # Helpers

  defp fetch_or_build_profile(user_id, _state) do
    user = Repo.get!(ViralEngine.Accounts.User, user_id)

    %{
      user_id: user.id,
      first_name: user.name |> String.split() |> List.first(),
      persona: String.to_atom(user.persona || "student"),
      grade_level: user.grade_level || 9,
      subjects: user.subjects || ["math"],
      engagement_level: :medium,
      communication_style: user.communication_style || "friendly"
    }
  end

  defp _determine_persona(user) do
    # Simple heuristic; expand as needed
    cond do
      user.email =~ "tutor" -> :tutor
      user.email =~ "parent" -> :parent
      true -> :student
    end
  end

  defp get_template(loop_type, persona, state) do
    state.copy_templates
    |> Map.get(loop_type, %{})
    |> Map.get(persona, default_template())
  end

  defp load_copy_templates do
    %{
      buddy_challenge: %{
        student: %{
          headline: "{{name}}, challenge a friend to beat your score!",
          body:
            "You nailed {{subject}} with {{score}}%. Think your friends can do better? Challenge them and you'll both get rewards! 🎯"
        },
        parent: %{
          headline: "{{name}}'s doing great! Time to challenge classmates.",
          body:
            "Your child scored {{score}}% on {{subject}}. Friendly competition helps learning stick!"
        }
      },
      results_rally: %{
        student: %{
          headline: "Check out my {{subject}} results!",
          body:
            "{{achievement}} See how you stack up against your peers and climb the leaderboard."
        },
        parent: %{
          headline: "{{name}}'s {{subject}} results are in!",
          body:
            "Your child's {{subject}} skills are improving. Share the progress with other parents!"
        }
      }
    }
  end

  defp default_template do
    %{
      headline: "Great work, {{name}}!",
      body: "Keep it up and share your progress with friends!"
    }
  end

  defp suggest_next_step(context, profile) do
    cond do
      length(context[:skill_gaps] || []) > 0 ->
        "master #{hd(context[:skill_gaps])}"

      profile.engagement_level == :low ->
        "keep your streak going"

      true ->
        "level up your skills"
    end
  end


  defp log_personalization(user_id, loop_type, result) do
    # Log to analytics (placeholder for now)
    Logger.info("Personalized content for user #{user_id}: #{loop_type} -> #{result.reward.type}")
  end
end
