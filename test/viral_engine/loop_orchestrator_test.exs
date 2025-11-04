defmodule ViralEngine.LoopOrchestratorTest do
  use ViralEngine.DataCase, async: false

  alias ViralEngine.{LoopOrchestrator, ViralPromptLog, ViralPrompts}

  setup do
    # Ensure GenServer is started
    start_supervised!(LoopOrchestrator)
    :ok
  end

  describe "trigger_loop/3" do
    test "triggers buddy_challenge prompt on practice completion" do
      user_id = 123
      event_data = %{session_id: 1, score: 95}

      # First trigger should succeed
      assert {:ok, prompt} = LoopOrchestrator.trigger_loop(:practice_completed, user_id, event_data)
      assert prompt.loop_type == :buddy_challenge
      assert prompt.variant in ["control", "competitive", "collaborative"]
      assert is_binary(prompt.prompt)
    end

    test "triggers flashcard_master prompt on flashcard completion" do
      user_id = 456
      event_data = %{session_id: 2, score: 100, cards_mastered: 25}

      assert {:ok, prompt} = LoopOrchestrator.trigger_loop(:flashcard_session_completed, user_id, event_data)
      assert prompt.loop_type == :flashcard_master
      assert is_binary(prompt.prompt)
    end

    test "returns no_prompt for unknown event type" do
      user_id = 789
      assert {:no_prompt, :no_matching_loop} = LoopOrchestrator.trigger_loop(:unknown_event, user_id, %{})
    end
  end

  describe "throttling" do
    test "throttles user after max daily prompts" do
      user_id = 999

      # Insert 3 recent prompts (max_prompts_per_day = 3)
      for i <- 1..3 do
        Repo.insert!(%ViralPromptLog{
          user_id: user_id,
          loop_type: "buddy_challenge",
          variant: "control",
          prompt_text: "Test prompt #{i}",
          shown_at: DateTime.utc_now()
        })
      end

      # Next trigger should be throttled
      assert {:throttled, :max_daily_limit} = LoopOrchestrator.trigger_loop(:practice_completed, user_id, %{})
    end

    test "respects loop-specific cooldown" do
      user_id = 888

      # Insert a recent buddy_challenge prompt (cooldown = 4 hours)
      Repo.insert!(%ViralPromptLog{
        user_id: user_id,
        loop_type: "buddy_challenge",
        variant: "control",
        prompt_text: "Test prompt",
        shown_at: DateTime.utc_now()
      })

      # Same loop type should be throttled
      assert {:throttled, :loop_cooldown} = LoopOrchestrator.trigger_loop(:practice_completed, user_id, %{})
    end

    test "allows prompts after cooldown period" do
      user_id = 777

      # Insert old prompt (25 hours ago)
      old_time = DateTime.utc_now() |> DateTime.add(-25 * 3600, :second)
      Repo.insert!(%ViralPromptLog{
        user_id: user_id,
        loop_type: "buddy_challenge",
        variant: "control",
        prompt_text: "Old prompt",
        shown_at: old_time
      })

      # Should allow new prompt
      assert {:ok, _prompt} = LoopOrchestrator.trigger_loop(:practice_completed, user_id, %{})
    end
  end

  describe "A/B testing" do
    test "assigns variant consistently for same user and loop" do
      user_id = 555
      loop_type = :buddy_challenge

      # Get variant multiple times
      variant1 = LoopOrchestrator.get_variant(user_id, loop_type)
      variant2 = LoopOrchestrator.get_variant(user_id, loop_type)

      # Should be the same variant
      assert variant1 == variant2
    end

    test "distributes variants across users" do
      # Test with multiple users
      variants = for user_id <- 1..100 do
        {:ok, prompt} = LoopOrchestrator.trigger_loop(:practice_completed, user_id * 1000, %{})
        prompt.variant
      end

      # Should have multiple different variants
      unique_variants = Enum.uniq(variants)
      assert length(unique_variants) > 1
    end
  end

  describe "fallback behavior" do
    test "returns default prompt when loop orchestrator unavailable" do
      default = ViralPrompts.get_default_prompt(:practice_completed)

      assert default.loop_type == :buddy_challenge
      assert default.variant == "default"
      assert is_binary(default.prompt)
    end

    test "has fallback prompts for all event types" do
      assert ViralPrompts.get_default_prompt(:practice_completed)
      assert ViralPrompts.get_default_prompt(:diagnostic_completed)
      assert ViralPrompts.get_default_prompt(:flashcard_session_completed)
      assert ViralPrompts.get_default_prompt(:achievement_unlocked)
    end
  end

  describe "PubSub integration" do
    test "broadcasts viral events" do
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "viral:loops")

      user_id = 321
      event_data = %{score: 85}

      LoopOrchestrator.broadcast_event(:practice_completed, user_id, event_data)

      # Should receive PubSub message
      assert_receive {:viral_event, %{type: :practice_completed, user_id: ^user_id, data: ^event_data}}, 1000
    end
  end

  describe "conversion tracking" do
    test "records prompt clicks" do
      log = Repo.insert!(%ViralPromptLog{
        user_id: 111,
        loop_type: "buddy_challenge",
        variant: "control",
        prompt_text: "Test",
        shown_at: DateTime.utc_now(),
        clicked: false
      })

      ViralPrompts.record_click(log.id)

      updated = Repo.get!(ViralPromptLog, log.id)
      assert updated.clicked == true
      assert updated.clicked_at != nil
    end

    test "records conversions" do
      log = Repo.insert!(%ViralPromptLog{
        user_id: 222,
        loop_type: "results_rally",
        variant: "control",
        prompt_text: "Test",
        shown_at: DateTime.utc_now(),
        converted: false
      })

      ViralPrompts.record_conversion(log.id)

      updated = Repo.get!(ViralPromptLog, log.id)
      assert updated.converted == true
      assert updated.converted_at != nil
    end

    test "calculates conversion rates" do
      loop_type = "buddy_challenge"
      variant = "test_variant"

      # Insert test data: 10 shown, 5 clicked, 2 converted
      for i <- 1..10 do
        clicked = i <= 5
        converted = i <= 2

        Repo.insert!(%ViralPromptLog{
          user_id: i,
          loop_type: loop_type,
          variant: variant,
          prompt_text: "Test",
          shown_at: DateTime.utc_now(),
          clicked: clicked,
          clicked_at: if(clicked, do: DateTime.utc_now(), else: nil),
          converted: converted,
          converted_at: if(converted, do: DateTime.utc_now(), else: nil)
        })
      end

      stats = ViralPromptLog.get_conversion_rate(loop_type, variant)

      assert stats.total == 10
      assert stats.clicks == 5
      assert stats.conversions == 2
      assert stats.click_rate == 50.0
      assert stats.conversion_rate == 20.0
    end
  end

  describe "performance metrics" do
    test "gets performance metrics for all loops" do
      # Insert sample data
      Repo.insert!(%ViralPromptLog{
        user_id: 1,
        loop_type: "buddy_challenge",
        variant: "control",
        prompt_text: "Test",
        shown_at: DateTime.utc_now(),
        clicked: true,
        converted: false
      })

      metrics = ViralPrompts.get_performance_metrics()

      assert is_list(metrics)
      assert length(metrics) > 0

      metric = hd(metrics)
      assert Map.has_key?(metric, :loop_type)
      assert Map.has_key?(metric, :variant)
      assert Map.has_key?(metric, :click_rate)
      assert Map.has_key?(metric, :conversion_rate)
    end

    test "filters metrics by loop type" do
      Repo.insert!(%ViralPromptLog{
        user_id: 1,
        loop_type: "buddy_challenge",
        variant: "control",
        prompt_text: "Test",
        shown_at: DateTime.utc_now()
      })

      Repo.insert!(%ViralPromptLog{
        user_id: 2,
        loop_type: "results_rally",
        variant: "control",
        prompt_text: "Test",
        shown_at: DateTime.utc_now()
      })

      metrics = ViralPrompts.get_performance_metrics("buddy_challenge")

      assert Enum.all?(metrics, fn m -> m.loop_type == "buddy_challenge" end)
    end
  end
end
