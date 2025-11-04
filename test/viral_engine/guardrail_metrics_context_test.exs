defmodule ViralEngine.GuardrailMetricsContextTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.GuardrailMetricsContext
  alias ViralEngine.{AttributionEvent, AttributionLink, ParentShare, ProgressReel, StudySession, Repo}

  # Helper function to create attribution events
  defp create_attribution_event(attrs \\ %{}) do
    default_attrs = %{
      event_type: "click",
      ip_address: "192.168.1.1",
      device_fingerprint: "device_123",
      referrer_id: 1,
      inserted_at: DateTime.utc_now()
    }

    {:ok, event} =
      default_attrs
      |> Map.merge(attrs)
      |> then(&struct(AttributionEvent, &1))
      |> Repo.insert()

    event
  end

  # Helper function to create parent shares
  defp create_parent_share(attrs \\ %{}) do
    default_attrs = %{
      user_id: 1,
      share_data: %{},
      view_count: 0,
      inserted_at: DateTime.utc_now()
    }

    {:ok, share} =
      default_attrs
      |> Map.merge(attrs)
      |> then(&struct(ParentShare, &1))
      |> Repo.insert()

    share
  end

  # Helper function to create progress reels
  defp create_progress_reel(attrs \\ %{}) do
    default_attrs = %{
      user_id: 1,
      reel_data: %{},
      inserted_at: DateTime.utc_now()
    }

    {:ok, reel} =
      default_attrs
      |> Map.merge(attrs)
      |> then(&struct(ProgressReel, &1))
      |> Repo.insert()

    reel
  end

  # Helper function to create study sessions
  defp create_study_session(attrs \\ %{}) do
    default_attrs = %{
      session_name: "Test Session",
      participant_ids: [1, 2, 3],
      inserted_at: DateTime.utc_now()
    }

    {:ok, session} =
      default_attrs
      |> Map.merge(attrs)
      |> then(&struct(StudySession, &1))
      |> Repo.insert()

    session
  end

  # Helper function to create attribution links
  defp create_attribution_link(attrs \\ %{}) do
    default_attrs = %{
      user_id: 1,
      click_count: 0,
      inserted_at: DateTime.utc_now()
    }

    {:ok, link} =
      default_attrs
      |> Map.merge(attrs)
      |> then(&struct(AttributionLink, &1))
      |> Repo.insert()

    link
  end

  describe "detect_suspicious_clicks/1" do
    test "flags IP with clicks exceeding threshold" do
      # Create 15 clicks from same IP on same day
      ip = "192.168.1.100"

      for _ <- 1..15 do
        create_attribution_event(%{
          ip_address: ip,
          event_type: "click",
          inserted_at: DateTime.utc_now()
        })
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      assert result.total_flagged_ips >= 1
      assert result.threshold_used == 10

      flagged_ip = Enum.find(result.suspicious_ips, fn s -> s.ip_address == ip end)
      assert flagged_ip != nil
      assert flagged_ip.click_count >= 11
    end

    test "returns empty when no fraud detected" do
      # Create 5 clicks from different IPs
      for i <- 1..5 do
        create_attribution_event(%{
          ip_address: "192.168.1.#{i}",
          event_type: "click"
        })
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      assert result.total_flagged_ips == 0
      assert result.suspicious_ips == []
    end

    test "does not flag IPs at exact threshold" do
      # Create exactly 10 clicks from same IP
      ip = "192.168.1.200"

      for _ <- 1..10 do
        create_attribution_event(%{ip_address: ip, event_type: "click"})
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      assert result.total_flagged_ips == 0
    end

    test "handles empty database" do
      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 7, threshold: 10)

      assert result.total_flagged_ips == 0
      assert result.suspicious_ips == []
      assert result.threshold_used == 10
    end

    test "respects custom days parameter" do
      # Create old event (8 days ago)
      old_time = DateTime.utc_now() |> DateTime.add(-8 * 86400, :second)

      for _ <- 1..15 do
        create_attribution_event(%{
          ip_address: "192.168.1.100",
          event_type: "click",
          inserted_at: old_time
        })
      end

      # Query for last 7 days - should find nothing
      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 7, threshold: 10)

      assert result.total_flagged_ips == 0
    end

    test "handles nil IP addresses" do
      # Create events with nil IP
      for _ <- 1..15 do
        create_attribution_event(%{ip_address: nil, event_type: "click"})
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 1, threshold: 10)

      # Should not crash, may or may not flag nil IPs depending on implementation
      assert is_integer(result.total_flagged_ips)
      assert is_list(result.suspicious_ips)
    end

    test "handles same IP on different days" do
      ip = "192.168.1.100"
      today = DateTime.utc_now()
      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 86400, :second)

      # 15 clicks today
      for _ <- 1..15 do
        create_attribution_event(%{
          ip_address: ip,
          event_type: "click",
          inserted_at: today
        })
      end

      # 15 clicks yesterday
      for _ <- 1..15 do
        create_attribution_event(%{
          ip_address: ip,
          event_type: "click",
          inserted_at: yesterday
        })
      end

      result = GuardrailMetricsContext.detect_suspicious_clicks(days: 7, threshold: 10)

      # Should flag IP for both days
      flagged_entries = Enum.filter(result.suspicious_ips, fn s -> s.ip_address == ip end)
      assert length(flagged_entries) >= 2
    end
  end

  describe "detect_bot_behavior/1" do
    test "flags device with rapid clicks within time window" do
      device = "bot_device_123"
      base_time = DateTime.utc_now()

      # Create 5 clicks within 3 seconds
      for i <- 0..4 do
        create_attribution_event(%{
          device_fingerprint: device,
          event_type: "click",
          inserted_at: DateTime.add(base_time, i, :second)
        })
      end

      result = GuardrailMetricsContext.detect_bot_behavior(days: 1, time_window: 5, min_clicks: 3)

      assert result.total_flagged_devices >= 1

      flagged_device = Enum.find(result.bot_like_devices, fn d -> d.device_fingerprint == device end)
      assert flagged_device != nil
      assert flagged_device.total_clicks >= 3
    end

    test "does not flag device with slow clicks" do
      device = "normal_device_456"
      base_time = DateTime.utc_now()

      # Create 5 clicks with 10 second gaps
      for i <- 0..4 do
        create_attribution_event(%{
          device_fingerprint: device,
          event_type: "click",
          inserted_at: DateTime.add(base_time, i * 10, :second)
        })
      end

      result = GuardrailMetricsContext.detect_bot_behavior(days: 1, time_window: 5, min_clicks: 3)

      assert result.total_flagged_devices == 0
    end

    test "handles empty database" do
      result = GuardrailMetricsContext.detect_bot_behavior(days: 7)

      assert result.total_flagged_devices == 0
      assert result.bot_like_devices == []
      assert is_map(result.detection_params)
    end

    test "handles single click per device" do
      for i <- 1..5 do
        create_attribution_event(%{
          device_fingerprint: "device_#{i}",
          event_type: "click"
        })
      end

      result = GuardrailMetricsContext.detect_bot_behavior(days: 1, time_window: 5, min_clicks: 3)

      assert result.total_flagged_devices == 0
    end

    test "flags device at exact threshold boundary" do
      device = "boundary_device"
      base_time = DateTime.utc_now()

      # Create exactly 3 clicks within exactly 5 seconds
      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: base_time
      })

      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: DateTime.add(base_time, 2, :second)
      })

      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: DateTime.add(base_time, 5, :second)
      })

      result = GuardrailMetricsContext.detect_bot_behavior(days: 1, time_window: 5, min_clicks: 3)

      # Should flag since 3 clicks within 5 seconds
      flagged = Enum.find(result.bot_like_devices, fn d -> d.device_fingerprint == device end)
      assert flagged != nil
    end

    test "does not flag device just outside time window" do
      device = "outside_window_device"
      base_time = DateTime.utc_now()

      # Create 3 clicks spanning 6 seconds (just outside 5 second window)
      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: base_time
      })

      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: DateTime.add(base_time, 3, :second)
      })

      create_attribution_event(%{
        device_fingerprint: device,
        inserted_at: DateTime.add(base_time, 6, :second)
      })

      result = GuardrailMetricsContext.detect_bot_behavior(days: 1, time_window: 5, min_clicks: 3)

      # Should not flag
      assert result.total_flagged_devices == 0
    end
  end

  describe "compute_opt_out_rates/1" do
    test "calculates correct percentage for parent shares" do
      # Create 10 shares: 3 never viewed, 7 viewed
      for _ <- 1..3 do
        create_parent_share(%{view_count: 0})
      end

      for _ <- 1..7 do
        create_parent_share(%{view_count: 5})
      end

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.parent_shares.total == 10
      assert result.parent_shares.never_viewed == 3
      assert result.parent_shares.opt_out_rate == 30.0
    end

    test "handles zero denominators for parent shares" do
      # No parent shares created
      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.parent_shares.total == 0
      assert result.parent_shares.never_viewed == 0
      assert result.parent_shares.opt_out_rate == 0.0
    end

    test "calculates 100% opt-out rate" do
      # All shares never viewed
      for _ <- 1..5 do
        create_parent_share(%{view_count: 0})
      end

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.parent_shares.opt_out_rate == 100.0
    end

    test "calculates 0% opt-out rate" do
      # All shares viewed
      for _ <- 1..5 do
        create_parent_share(%{view_count: 10})
      end

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.parent_shares.opt_out_rate == 0.0
    end

    test "calculates attribution link opt-out rates" do
      # Create links: 2 with zero clicks, 8 with clicks
      for _ <- 1..2 do
        create_attribution_link(%{click_count: 0})
      end

      for _ <- 1..8 do
        create_attribution_link(%{click_count: 5})
      end

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.attribution_links.total == 10
      assert result.attribution_links.zero_clicks == 2
      assert result.attribution_links.opt_out_rate == 20.0
    end

    test "calculates average participants for study sessions" do
      # Create sessions with different participant counts
      create_study_session(%{participant_ids: [1, 2, 3]})
      create_study_session(%{participant_ids: [1, 2, 3, 4, 5]})
      create_study_session(%{participant_ids: [1]})

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.study_sessions.total == 3
      # Average: (3 + 5 + 1) / 3 = 3.0
      assert result.study_sessions.avg_participants == 3.0
    end

    test "handles study sessions with empty participant arrays" do
      create_study_session(%{participant_ids: []})
      create_study_session(%{participant_ids: [1, 2]})

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      assert result.study_sessions.total == 2
      # Average: (0 + 2) / 2 = 1.0
      assert result.study_sessions.avg_participants == 1.0
    end

    test "respects date range filtering" do
      # Create old share (35 days ago)
      old_time = DateTime.utc_now() |> DateTime.add(-35 * 86400, :second)
      create_parent_share(%{view_count: 0, inserted_at: old_time})

      # Create recent share
      create_parent_share(%{view_count: 0, inserted_at: DateTime.utc_now()})

      result = GuardrailMetricsContext.compute_opt_out_rates(days: 30)

      # Should only count the recent share
      assert result.parent_shares.total == 1
    end
  end

  describe "monitor_coppa_compliance/1" do
    test "detects PII in parent share data" do
      # Create share with PII in share_data
      create_parent_share(%{
        share_data: %{
          "user_email" => "parent@example.com",
          "message" => "Check this out!"
        }
      })

      # Create share without PII
      create_parent_share(%{
        share_data: %{
          "message" => "Great progress!",
          "theme" => "blue"
        }
      })

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      assert result.parent_shares.total_checked == 2
      assert result.parent_shares.violations_found == 1
      assert result.parent_shares.compliance_rate == 50.0
    end

    test "detects PII in progress reel data" do
      # Create reel with PII
      create_progress_reel(%{
        reel_data: %{
          "phone" => "555-1234",
          "content" => "Video content"
        }
      })

      # Create reel without PII
      create_progress_reel(%{
        reel_data: %{
          "content" => "Video content",
          "duration" => 30
        }
      })

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      assert result.progress_reels.total_checked == 2
      assert result.progress_reels.violations_found == 1
      assert result.progress_reels.compliance_rate == 50.0
    end

    test "returns 100% compliance when no PII detected" do
      # Create clean shares and reels
      create_parent_share(%{share_data: %{"message" => "Clean message"}})
      create_progress_reel(%{reel_data: %{"content" => "Clean content"}})

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      assert result.parent_shares.compliance_rate == 100.0
      assert result.progress_reels.compliance_rate == 100.0
      assert result.overall_compliance_rate == 100.0
    end

    test "returns 0% compliance when all contain PII" do
      # Create shares with PII
      create_parent_share(%{share_data: %{"email" => "test@example.com"}})
      create_parent_share(%{share_data: %{"address" => "123 Main St"}})

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      assert result.parent_shares.compliance_rate == 0.0
    end

    test "handles empty database" do
      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      assert result.parent_shares.total_checked == 0
      assert result.parent_shares.violations_found == 0
      assert result.parent_shares.compliance_rate == 100.0
      assert result.progress_reels.total_checked == 0
      assert result.overall_compliance_rate == 100.0
    end

    test "handles nil share_data and reel_data" do
      # Create records with nil data
      create_parent_share(%{share_data: nil})
      create_progress_reel(%{reel_data: nil})

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      # Should not crash, should treat nil as safe (no PII)
      assert is_float(result.parent_shares.compliance_rate)
      assert is_float(result.progress_reels.compliance_rate)
    end

    test "calculates overall compliance rate correctly" do
      # 2 parent shares: 1 violation (50%)
      create_parent_share(%{share_data: %{"email" => "test@example.com"}})
      create_parent_share(%{share_data: %{"message" => "Clean"}})

      # 2 progress reels: 0 violations (100%)
      create_progress_reel(%{reel_data: %{"content" => "Clean"}})
      create_progress_reel(%{reel_data: %{"content" => "Also clean"}})

      result = GuardrailMetricsContext.monitor_coppa_compliance(days: 30)

      # Overall: 1 violation out of 4 total = 75%
      assert result.overall_compliance_rate == 75.0
    end
  end

  describe "detect_conversion_anomalies/1" do
    test "flags referrer with excessive conversions per day" do
      referrer_id = 123
      today = DateTime.utc_now()

      # Create 15 conversions from same referrer on same day
      for _ <- 1..15 do
        create_attribution_event(%{
          referrer_id: referrer_id,
          event_type: "conversion",
          inserted_at: today
        })
      end

      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7, threshold: 10)

      assert length(result.suspicious_referrers) >= 1

      flagged = Enum.find(result.suspicious_referrers, fn s -> s.referrer_id == referrer_id end)
      assert flagged != nil
      assert flagged.conversion_count >= 11
    end

    test "flags referrer with suspiciously high conversion rate" do
      referrer_id = 456

      # Create 10 clicks
      for _ <- 1..10 do
        create_attribution_event(%{
          referrer_id: referrer_id,
          event_type: "click"
        })
      end

      # Create 9 conversions (90% rate)
      for _ <- 1..9 do
        create_attribution_event(%{
          referrer_id: referrer_id,
          event_type: "conversion"
        })
      end

      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7)

      assert length(result.high_conversion_rate_referrers) >= 1

      flagged = Enum.find(result.high_conversion_rate_referrers, fn r -> r.referrer_id == referrer_id end)
      assert flagged != nil
      assert flagged.conversion_rate > 80.0
    end

    test "does not flag referrer at exact 80% conversion rate threshold" do
      referrer_id = 789

      # Create 10 clicks and 8 conversions (exactly 80%)
      for _ <- 1..10 do
        create_attribution_event(%{referrer_id: referrer_id, event_type: "click"})
      end

      for _ <- 1..8 do
        create_attribution_event(%{referrer_id: referrer_id, event_type: "conversion"})
      end

      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7)

      # Should not flag at exactly 80%
      flagged = Enum.find(result.high_conversion_rate_referrers, fn r -> r.referrer_id == referrer_id end)
      assert flagged == nil
    end

    test "handles referrer with zero clicks" do
      referrer_id = 999

      # Create conversions with no clicks (shouldn't happen but test edge case)
      for _ <- 1..5 do
        create_attribution_event(%{referrer_id: referrer_id, event_type: "conversion"})
      end

      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7)

      # Should not crash, may or may not flag depending on implementation
      assert is_integer(result.total_flagged)
    end

    test "handles empty database" do
      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7)

      assert result.suspicious_referrers == []
      assert result.high_conversion_rate_referrers == []
      assert result.total_flagged == 0
    end

    test "calculates total flagged correctly" do
      # Create high volume referrer
      for _ <- 1..15 do
        create_attribution_event(%{referrer_id: 111, event_type: "conversion"})
      end

      # Create high rate referrer
      for _ <- 1..10 do
        create_attribution_event(%{referrer_id: 222, event_type: "click"})
      end

      for _ <- 1..9 do
        create_attribution_event(%{referrer_id: 222, event_type: "conversion"})
      end

      result = GuardrailMetricsContext.detect_conversion_anomalies(days: 7, threshold: 10)

      # Total flagged should be at least 2 (one from each category)
      assert result.total_flagged >= 2
    end
  end

  describe "compute_health_score/1" do
    test "calculates health score with no issues" do
      # Empty database = perfect health
      result = GuardrailMetricsContext.compute_health_score(days: 7)

      assert result.health_score == 100.0
      assert result.health_status == :excellent
      assert result.deductions.fraud == 0.0
      assert result.deductions.bot_behavior == 0.0
    end

    test "applies fraud deduction correctly" do
      # Create 10 suspicious IPs (should deduct 20 points: min(10 * 2, 30))
      for i <- 1..10 do
        for _ <- 1..15 do
          create_attribution_event(%{
            ip_address: "192.168.1.#{i}",
            event_type: "click"
          })
        end
      end

      result = GuardrailMetricsContext.compute_health_score(days: 1)

      assert result.deductions.fraud == 20.0
      assert result.health_score <= 80.0
    end

    test "enforces fraud deduction cap at 30 points" do
      # Create 20 suspicious IPs (would be 40 points, but capped at 30)
      for i <- 1..20 do
        for _ <- 1..15 do
          create_attribution_event(%{
            ip_address: "10.0.0.#{i}",
            event_type: "click"
          })
        end
      end

      result = GuardrailMetricsContext.compute_health_score(days: 1)

      assert result.deductions.fraud == 30.0
    end

    test "enforces minimum score of 0" do
      # Create massive fraud, bots, and COPPA violations
      # 20 suspicious IPs (30 point fraud cap)
      for i <- 1..20 do
        for _ <- 1..15 do
          create_attribution_event(%{ip_address: "10.0.#{i}.1", event_type: "click"})
        end
      end

      # 20 bot devices (20 point bot cap)
      for i <- 1..20 do
        base_time = DateTime.utc_now()

        for j <- 0..4 do
          create_attribution_event(%{
            device_fingerprint: "bot_#{i}",
            inserted_at: DateTime.add(base_time, j, :second)
          })
        end
      end

      # COPPA violations (30 point cap)
      for _ <- 1..10 do
        create_parent_share(%{share_data: %{"email" => "test@example.com"}})
      end

      # High opt-out rates (20 point cap)
      for _ <- 1..20 do
        create_parent_share(%{view_count: 0})
      end

      result = GuardrailMetricsContext.compute_health_score(days: 7)

      # Score should be >= 0 (floor enforced)
      assert result.health_score >= 0.0
      assert result.health_score <= 100.0
    end

    test "maps score to correct health status" do
      # Test boundaries
      # Score >= 90: excellent
      # Score >= 75: good
      # Score >= 60: fair
      # Score >= 40: warning
      # Score < 40: critical

      # We can't easily control exact score, but we can test the mapping logic exists
      result = GuardrailMetricsContext.compute_health_score(days: 7)

      assert result.health_status in [:excellent, :good, :fair, :warning, :critical]
    end

    test "includes all component metrics" do
      result = GuardrailMetricsContext.compute_health_score(days: 7)

      assert is_map(result.components.fraud)
      assert is_map(result.components.bots)
      assert is_map(result.components.opt_outs)
      assert is_map(result.components.coppa)
      assert is_map(result.components.anomalies)
    end

    test "rounds score to 1 decimal place" do
      result = GuardrailMetricsContext.compute_health_score(days: 7)

      # Check that score has at most 1 decimal place
      score_string = Float.to_string(result.health_score)
      [_integer, decimal] = String.split(score_string, ".")
      assert String.length(decimal) <= 1
    end
  end

  describe "get_active_alerts/1" do
    test "returns no alerts with perfect health" do
      # Empty database
      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      assert result.total_alerts == 0
      assert result.alerts == []
      assert result.health_score == 100.0
      assert result.health_status == :excellent
    end

    test "generates COPPA violation alert when violations found" do
      # Create parent share with PII violation
      create_parent_share(%{share_data: %{"email" => "test@example.com"}})

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      coppa_alert = Enum.find(result.alerts, fn a -> a.type == :coppa_violation end)
      assert coppa_alert != nil
      assert coppa_alert.severity == :critical
      assert is_binary(coppa_alert.message)
      assert %DateTime{} = coppa_alert.timestamp
    end

    test "generates fraud alert when >5 suspicious IPs" do
      # Create 6 suspicious IPs
      for i <- 1..6 do
        for _ <- 1..15 do
          create_attribution_event(%{
            ip_address: "192.168.1.#{i}",
            event_type: "click"
          })
        end
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      fraud_alert = Enum.find(result.alerts, fn a -> a.type == :fraud_detection end)
      assert fraud_alert != nil
      assert fraud_alert.severity == :high
    end

    test "does not generate fraud alert at exact threshold (5 IPs)" do
      # Create exactly 5 suspicious IPs
      for i <- 1..5 do
        for _ <- 1..15 do
          create_attribution_event(%{
            ip_address: "192.168.1.#{i}",
            event_type: "click"
          })
        end
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      fraud_alert = Enum.find(result.alerts, fn a -> a.type == :fraud_detection end)
      assert fraud_alert == nil
    end

    test "generates bot detection alert when >3 bot devices" do
      # Create 4 bot devices
      for i <- 1..4 do
        base_time = DateTime.utc_now()

        for j <- 0..4 do
          create_attribution_event(%{
            device_fingerprint: "bot_device_#{i}",
            inserted_at: DateTime.add(base_time, j, :second)
          })
        end
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      bot_alert = Enum.find(result.alerts, fn a -> a.type == :bot_detection end)
      assert bot_alert != nil
      assert bot_alert.severity == :medium
    end

    test "generates high opt-out alert when >30%" do
      # Create 10 shares: 4 never viewed (40% opt-out)
      for _ <- 1..4 do
        create_parent_share(%{view_count: 0})
      end

      for _ <- 1..6 do
        create_parent_share(%{view_count: 5})
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      opt_out_alert = Enum.find(result.alerts, fn a -> a.type == :high_opt_out end)
      assert opt_out_alert != nil
      assert opt_out_alert.severity == :medium
    end

    test "does not generate opt-out alert at exact 30% threshold" do
      # Create 10 shares: exactly 3 never viewed (30%)
      for _ <- 1..3 do
        create_parent_share(%{view_count: 0})
      end

      for _ <- 1..7 do
        create_parent_share(%{view_count: 5})
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      opt_out_alert = Enum.find(result.alerts, fn a -> a.type == :high_opt_out end)
      assert opt_out_alert == nil
    end

    test "generates multiple alerts simultaneously" do
      # Create COPPA violation
      create_parent_share(%{share_data: %{"email" => "test@example.com"}})

      # Create fraud (6 suspicious IPs)
      for i <- 1..6 do
        for _ <- 1..15 do
          create_attribution_event(%{ip_address: "192.168.1.#{i}", event_type: "click"})
        end
      end

      # Create bots (4 devices)
      for i <- 1..4 do
        base_time = DateTime.utc_now()

        for j <- 0..4 do
          create_attribution_event(%{
            device_fingerprint: "bot_#{i}",
            inserted_at: DateTime.add(base_time, j, :second)
          })
        end
      end

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      # Should have at least 3 alerts
      assert result.total_alerts >= 3
      assert length(result.alerts) >= 3
    end

    test "includes health score and status in result" do
      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      assert is_float(result.health_score)
      assert result.health_status in [:excellent, :good, :fair, :warning, :critical]
    end

    test "all alerts have required fields" do
      # Create some violations to generate alerts
      create_parent_share(%{share_data: %{"email" => "test@example.com"}})

      result = GuardrailMetricsContext.get_active_alerts(days: 7)

      for alert <- result.alerts do
        assert alert.severity in [:critical, :high, :medium]
        assert is_atom(alert.type)
        assert is_binary(alert.message)
        assert %DateTime{} = alert.timestamp
      end
    end
  end
end
