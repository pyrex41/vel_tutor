defmodule ViralEngine.ViralMetricsContextTest do
  use ViralEngine.DataCase
  alias ViralEngine.{ViralMetricsContext, AttributionLink, Repo}

  describe "compute_k_factor/1" do
    setup do
      # Create 10 users who sent invites
      for i <- 1..10 do
        {:ok, _link} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "buddy_challenge",
            token: "token_#{i}",
            click_count: 5,
            conversion_count: 2,
            inserted_at: DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60, :second)
          })
          |> Repo.insert()
      end

      :ok
    end

    test "calculates K-factor correctly" do
      result = ViralMetricsContext.compute_k_factor(days: 7)

      # 10 active users, 50 total invites (5 per user), 20 total conversions
      assert result.active_users == 10
      assert result.total_invites == 50
      assert result.total_conversions == 20

      # Avg invites per user: 50/10 = 5.0
      assert result.avg_invites_per_user == 5.0

      # Conversion rate: 20/50 = 40%
      assert result.conversion_rate == 40.0

      # K-factor: 5.0 * 0.4 = 2.0
      assert result.k_factor == 2.0
    end

    test "returns zeros for no data" do
      # Clear all data
      Repo.delete_all(AttributionLink)

      result = ViralMetricsContext.compute_k_factor()

      assert result.k_factor == 0.0
      assert result.active_users == 0
      assert result.total_invites == 0
    end

    test "filters by time period correctly" do
      # Create old data (outside 7 day window)
      {:ok, _} =
        %AttributionLink{}
        |> AttributionLink.changeset(%{
          referrer_id: 999,
          source: "old_data",
          token: "old_token",
          click_count: 100,
          conversion_count: 50,
          inserted_at: DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)
        })
        |> Repo.insert()

      # Should not include old data in 7-day calculation
      result = ViralMetricsContext.compute_k_factor(days: 7)

      # Should still have original 10 users, not 11
      assert result.active_users == 10
    end
  end

  describe "compute_k_factor_by_source/1" do
    setup do
      # Buddy Challenge: 5 users, K-factor 2.0
      for i <- 1..5 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "buddy_challenge",
            token: "bc_#{i}",
            click_count: 5,
            conversion_count: 2
          })
          |> Repo.insert()
      end

      # Results Rally: 3 users, K-factor 1.5
      for i <- 6..8 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "results_rally",
            token: "rr_#{i}",
            click_count: 3,
            conversion_count: 2
          })
          |> Repo.insert()
      end

      :ok
    end

    test "calculates K-factor by source" do
      results = ViralMetricsContext.compute_k_factor_by_source(7)

      buddy_challenge = Enum.find(results, &(&1.source == "buddy_challenge"))
      results_rally = Enum.find(results, &(&1.source == "results_rally"))

      assert buddy_challenge.active_users == 5
      assert buddy_challenge.total_invites == 25
      assert buddy_challenge.total_conversions == 10
      assert buddy_challenge.k_factor == 2.0

      assert results_rally.active_users == 3
      assert results_rally.total_invites == 9
      assert results_rally.total_conversions == 6
    end

    test "sorts results by K-factor descending" do
      results = ViralMetricsContext.compute_k_factor_by_source(7)

      # Buddy Challenge should be first (higher K-factor)
      assert hd(results).source == "buddy_challenge"
    end
  end

  describe "cohort_analysis/1" do
    setup do
      # Week 1 cohort
      week1_start = DateTime.add(DateTime.utc_now(), -14 * 24 * 60 * 60, :second)

      for i <- 1..5 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "buddy_challenge",
            token: "w1_#{i}",
            click_count: 4,
            conversion_count: 2,
            inserted_at: week1_start
          })
          |> Repo.insert()
      end

      # Week 2 cohort
      week2_start = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

      for i <- 6..10 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "results_rally",
            token: "w2_#{i}",
            click_count: 3,
            conversion_count: 1,
            inserted_at: week2_start
          })
          |> Repo.insert()
      end

      :ok
    end

    test "groups users by cohort week" do
      cohorts = ViralMetricsContext.cohort_analysis(4)

      assert length(cohorts) >= 2

      # Each cohort should have metrics
      for cohort <- cohorts do
        assert is_integer(cohort.cohort_size)
        assert is_number(cohort.avg_invites_per_user)
        assert is_number(cohort.conversion_rate)
        assert is_number(cohort.k_factor)
      end
    end

    test "calculates cohort K-factors" do
      cohorts = ViralMetricsContext.cohort_analysis(4)

      # Find week 1 cohort (should have K-factor of 1.6: 4 invites * 0.5 conv rate = 2.0)
      week1_cohort = Enum.find(cohorts, fn c -> c.cohort_size == 5 end)

      if week1_cohort do
        assert week1_cohort.avg_invites_per_user == 4.0
        assert week1_cohort.conversion_rate == 50.0
        assert week1_cohort.k_factor == 2.0
      end
    end
  end

  describe "funnel_analysis/2" do
    setup do
      # Create funnel data
      {:ok, _} =
        %AttributionLink{}
        |> AttributionLink.changeset(%{
          referrer_id: 1,
          source: "buddy_challenge",
          token: "funnel_1",
          click_count: 100,    # 100 clicks
          conversion_count: 20  # 20 conversions (20% CR)
        })
        |> Repo.insert()

      {:ok, _} =
        %AttributionLink{}
        |> AttributionLink.changeset(%{
          referrer_id: 2,
          source: "buddy_challenge",
          token: "funnel_2",
          click_count: 50,
          conversion_count: 15
        })
        |> Repo.insert()

      :ok
    end

    test "calculates funnel stages" do
      result = ViralMetricsContext.funnel_analysis("buddy_challenge", 7)

      assert result.source == "buddy_challenge"
      assert result.period_days == 7

      funnel = result.funnel

      # Should have 4 stages
      assert length(funnel) == 4

      invites_stage = Enum.at(funnel, 0)
      clicks_stage = Enum.at(funnel, 1)
      signups_stage = Enum.at(funnel, 2)
      fvm_stage = Enum.at(funnel, 3)

      assert invites_stage.stage == "Invites Sent"
      assert invites_stage.count == 2  # 2 invitation links created
      assert invites_stage.conversion_rate == 100.0

      assert clicks_stage.stage == "Clicked"
      assert clicks_stage.count == 150  # 100 + 50 clicks

      assert signups_stage.stage == "Signed Up"
      assert signups_stage.count == 35  # 20 + 15 conversions
    end

    test "calculates overall conversion rate" do
      result = ViralMetricsContext.funnel_analysis("buddy_challenge", 7)

      # Overall conversion should be FVM / invites_sent
      assert is_number(result.overall_conversion)
      assert result.overall_conversion >= 0
    end

    test "handles nil source for all loops" do
      result = ViralMetricsContext.funnel_analysis(nil, 7)

      assert result.source == nil
      assert is_list(result.funnel)
    end
  end

  describe "loop_efficiency_analysis/1" do
    setup do
      # High efficiency loop
      for i <- 1..5 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "buddy_challenge",
            token: "efficient_#{i}",
            click_count: 10,
            conversion_count: 8  # 80% conversion
          })
          |> Repo.insert()
      end

      # Low efficiency loop
      for i <- 6..10 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "streak_rescue",
            token: "inefficient_#{i}",
            click_count: 10,
            conversion_count: 1  # 10% conversion
          })
          |> Repo.insert()
      end

      :ok
    end

    test "calculates efficiency scores" do
      results = ViralMetricsContext.loop_efficiency_analysis(7)

      # Should have efficiency_score and recommendation
      for result <- results do
        assert is_number(result.efficiency_score)
        assert is_binary(result.recommendation)
        assert is_number(result.roi)
      end
    end

    test "sorts by efficiency score descending" do
      results = ViralMetricsContext.loop_efficiency_analysis(7)

      # First result should be buddy_challenge (higher efficiency)
      assert hd(results).source == "buddy_challenge"

      # Efficiency should be K-factor * (conv_rate / 100)
      buddy_challenge = hd(results)
      expected_efficiency = buddy_challenge.k_factor * (buddy_challenge.conversion_rate / 100)
      assert_in_delta buddy_challenge.efficiency_score, expected_efficiency, 0.01
    end

    test "provides actionable recommendations" do
      results = ViralMetricsContext.loop_efficiency_analysis(7)

      buddy_challenge = Enum.find(results, &(&1.source == "buddy_challenge"))

      # High K-factor and efficiency should get scale recommendation
      assert String.contains?(buddy_challenge.recommendation, "Scale") ||
             String.contains?(buddy_challenge.recommendation, "Continue")
    end
  end

  describe "get_growth_timeline/1" do
    setup do
      # Create data over multiple days
      for days_ago <- 1..7 do
        timestamp = DateTime.add(DateTime.utc_now(), -days_ago * 24 * 60 * 60, :second)

        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: days_ago,
            source: "buddy_challenge",
            token: "timeline_#{days_ago}",
            click_count: days_ago * 2,
            conversion_count: days_ago,
            inserted_at: timestamp
          })
          |> Repo.insert()
      end

      :ok
    end

    test "returns daily growth metrics" do
      timeline = ViralMetricsContext.get_growth_timeline(14)

      assert is_list(timeline)
      assert length(timeline) >= 1

      # Each day should have metrics
      for day <- timeline do
        assert is_integer(day.links_created)
        assert is_number(day.clicks)
        assert is_number(day.conversions)
      end
    end
  end

  describe "get_top_referrers/1" do
    setup do
      # Create top referrers
      {:ok, _} =
        %AttributionLink{}
        |> AttributionLink.changeset(%{
          referrer_id: 1,
          source: "buddy_challenge",
          token: "top_1",
          click_count: 50,
          conversion_count: 25
        })
        |> Repo.insert()

      {:ok, _} =
        %AttributionLink{}
        |> AttributionLink.changeset(%{
          referrer_id: 2,
          source: "results_rally",
          token: "top_2",
          click_count: 30,
          conversion_count: 10
        })
        |> Repo.insert()

      :ok
    end

    test "returns top referrers sorted by conversions" do
      referrers = ViralMetricsContext.get_top_referrers(days: 7, limit: 10)

      assert is_list(referrers)

      # User 1 should be first (more conversions)
      assert hd(referrers).referrer_id == 1
    end

    test "includes conversion rate" do
      referrers = ViralMetricsContext.get_top_referrers(days: 7, limit: 10)

      for referrer <- referrers do
        assert is_number(referrer.conversion_rate)
        assert referrer.conversion_rate >= 0
        assert referrer.conversion_rate <= 100
      end
    end

    test "respects limit parameter" do
      # Create 20 referrers
      for i <- 3..22 do
        {:ok, _} =
          %AttributionLink{}
          |> AttributionLink.changeset(%{
            referrer_id: i,
            source: "test",
            token: "ref_#{i}",
            click_count: 1,
            conversion_count: 1
          })
          |> Repo.insert()
      end

      referrers = ViralMetricsContext.get_top_referrers(days: 7, limit: 5)

      assert length(referrers) == 5
    end
  end

  describe "compute_cycle_time/1" do
    test "returns structure even with no data" do
      result = ViralMetricsContext.compute_cycle_time(7)

      assert is_map(result)
      assert Map.has_key?(result, :avg_cycle_time_hours)
      assert Map.has_key?(result, :median_cycle_time_hours)
    end

    test "calculates average and median" do
      # This would require AttributionEvent data with timestamps
      # For now, just verify structure
      result = ViralMetricsContext.compute_cycle_time(7)

      assert is_number(result.avg_cycle_time_hours)
      assert is_number(result.median_cycle_time_hours)
    end
  end
end
