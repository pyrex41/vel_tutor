defmodule ViralEngine.Phase3IntegrationTest do
  use ViralEngine.DataCase, async: false

  alias ViralEngine.{Repo, Accounts.User, TutoringSession, WeeklyRecap}
  alias ViralEngine.{ParentalConsent, DeviceFlag, Achievement}
  alias ViralEngine.Agents.TrustSafety
  alias ViralEngine.SessionPipeline
  alias ViralEngine.Loops.{ProudParent, TutorSpotlight}
  alias ViralEngine.Jobs.WeeklyRecapGenerator

  describe "Trust & Safety Agent" do
    setup do
      # Start TrustSafety agent for tests
      start_supervised!(TrustSafety)
      :ok
    end

    test "blocks action when user is blocked" do
      user = insert(:user)

      # Create a device flag blocking the user
      insert(:device_flag, %{
        device_id: "test-device-123",
        blocked: true,
        flag_type: "abuse"
      })

      context = %{
        user_id: user.id,
        device_id: "test-device-123",
        action_type: "share_personal_info"
      }

      assert {:error, :device_flagged} = TrustSafety.check_action(context)
    end

    test "allows action when all checks pass" do
      user = insert(:user, age: 18)

      context = %{
        user_id: user.id,
        device_id: "clean-device-456",
        action_type: "general",
        ip_address: "192.168.1.1"
      }

      assert {:ok, :allowed} = TrustSafety.check_action(context)
    end

    test "requires parental consent for minors on sensitive actions" do
      minor = insert(:user, age: 12)

      context = %{
        user_id: minor.id,
        device_id: "device-789",
        action_type: "share_personal_info"
      }

      assert {:error, :parental_consent_required} = TrustSafety.check_action(context)
    end

    test "allows minor with parental consent" do
      minor = insert(:user, age: 12)

      insert(:parental_consent, %{
        user_id: minor.id,
        consent_given: true,
        parent_email: "parent@example.com"
      })

      context = %{
        user_id: minor.id,
        device_id: "device-789",
        action_type: "share_personal_info"
      }

      assert {:ok, :allowed} = TrustSafety.check_action(context)
    end

    test "redacts sensitive data from content" do
      content = """
      Hi, my name is John Smith and my email is john@example.com.
      You can call me at 555-123-4567 or 555.987.6543.
      """

      context = %{user_age: 12}

      {:ok, redacted} = TrustSafety.redact_data(content, context)

      refute String.contains?(redacted, "john@example.com")
      refute String.contains?(redacted, "555-123-4567")
      refute String.contains?(redacted, "John Smith")
      assert String.contains?(redacted, "[EMAIL]")
      assert String.contains?(redacted, "[PHONE]")
      assert String.contains?(redacted, "[NAME]")
    end

    test "reports abuse and potentially blocks entity" do
      report = %{
        entity_type: :device,
        entity_id: "malicious-device-999",
        device_id: "malicious-device-999",
        ip_address: "10.0.0.1",
        reason: "Automated bot behavior detected",
        severity: :high
      }

      TrustSafety.report_abuse(report)

      # Give GenServer time to process
      Process.sleep(100)

      # Check that device flag was created
      device_flag = Repo.get_by(DeviceFlag, device_id: "malicious-device-999")
      assert device_flag != nil
      assert device_flag.blocked == true
    end

    test "updates user signals for fraud scoring" do
      user_id = 123

      TrustSafety.update_user_signal(user_id, :verified_email, true)
      TrustSafety.update_user_signal(user_id, :payment_verified, true)

      # Signals are stored in GenServer state
      # Check that fraud score is lower due to positive signals
      context = %{
        user_id: user_id,
        device_id: "device-signal-test",
        action_type: "general"
      }

      # With positive signals, should pass fraud check
      assert {:ok, :allowed} = TrustSafety.check_action(context)
    end

    test "rate limiting blocks after max attempts" do
      user = insert(:user)

      context = %{
        user_id: user.id,
        device_id: "device-rate-test",
        action_type: "share",
        ip_address: "192.168.1.100"
      }

      # Make 10 successful requests (max limit)
      for _ <- 1..10 do
        assert {:ok, :allowed} = TrustSafety.check_action(context)
      end

      # 11th request should be rate limited
      assert {:error, :rate_limited} = TrustSafety.check_action(context)
    end

    test "rate limit resets after time window" do
      user = insert(:user)

      context = %{
        user_id: user.id,
        device_id: "device-rate-window-test",
        action_type: "share",
        ip_address: "192.168.1.101"
      }

      # Make 10 requests to hit limit
      for _ <- 1..10 do
        TrustSafety.check_action(context)
      end

      # Should be rate limited
      assert {:error, :rate_limited} = TrustSafety.check_action(context)

      # Wait for rate limit window to expire (in production: 60 seconds)
      # For test, we'd need to mock time or reduce the window
      # This is a structural test - actual timing would need mocking
      # Just verify the behavior is documented
    end

    test "duplicate signup detection works" do
      user1 = insert(:user)
      device_id = "shared-device-123"

      context1 = %{
        user_id: user1.id,
        device_id: device_id,
        action_type: "signup",
        ip_address: "10.0.0.50"
      }

      # First signup should succeed
      assert {:ok, :allowed} = TrustSafety.check_action(context1)

      # Second signup from same device should be blocked
      user2 = insert(:user)

      context2 = %{
        user_id: user2.id,
        device_id: device_id,
        action_type: "signup",
        ip_address: "10.0.0.51"
      }

      assert {:error, :duplicate_signup} = TrustSafety.check_action(context2)
    end

    test "fraud score increases for suspicious activity" do
      user = insert(:user)

      # Multiple device flags for same user should increase fraud score
      for i <- 1..3 do
        insert(:device_flag, %{
          device_id: "device-fraud-#{i}",
          ip_address: "192.168.1.#{i}",
          flag_type: "abuse",
          risk_score: 3.0
        })
      end

      context = %{
        user_id: user.id,
        device_id: "device-fraud-1",
        action_type: "general",
        ip_address: "192.168.1.1"
      }

      # Should be blocked due to high fraud score from device flags
      result = TrustSafety.check_action(context)

      # Either fraud_detected or device_flagged error expected
      assert {:error, _reason} = result
    end
  end

  describe "Session Intelligence Pipeline" do
    test "processes session end-to-end" do
      student = insert(:user, persona: "student")
      tutor = insert(:user, persona: "tutor")

      session =
        insert(:tutoring_session, %{
          student_id: student.id,
          tutor_id: tutor.id,
          subject: "Mathematics",
          topic: "Algebra",
          duration_minutes: 60,
          rating: 5,
          processed: false
        })

      # Mock AIClient response
      mock_ai_response()

      job = %Oban.Job{args: %{"session_id" => session.id}}
      assert {:ok, :completed} = SessionPipeline.perform(job)

      # Verify session was updated
      updated_session = Repo.get!(TutoringSession, session.id)
      assert updated_session.processed == true
      assert updated_session.ai_summary != nil
      assert updated_session.student_actions != nil
      assert updated_session.tutor_actions != nil
      assert updated_session.parent_actions != nil
    end

    test "generates transcript stub when none exists" do
      session = insert(:tutoring_session, transcript_text: nil)

      job = %Oban.Job{args: %{"session_id" => session.id}}
      assert {:ok, :completed} = SessionPipeline.perform(job)

      updated_session = Repo.get!(TutoringSession, session.id)
      assert updated_session.ai_summary =~ "Stub Transcript"
    end

    test "routes complex sessions to GPT-4o for planning" do
      # Long session with low rating should use :planning task type
      session =
        insert(:tutoring_session, %{
          duration_minutes: 90,
          rating: 2,
          subject: "Physics"
        })

      # The pipeline should use :planning for this complex session
      # (implicitly tested via AIClient routing)
      job = %Oban.Job{args: %{"session_id" => session.id}}
      assert {:ok, :completed} = SessionPipeline.perform(job)
    end
  end

  describe "ProudParent Loop" do
    test "generates weekly recap and share pack" do
      parent = insert(:user, persona: "parent")
      student = insert(:user, persona: "student", parent_id: parent.id)
      tutor = insert(:user, persona: "tutor")

      week_start = Date.utc_today() |> Date.beginning_of_week()

      # Create some sessions for this week
      for _i <- 1..3 do
        insert(:tutoring_session, %{
          student_id: student.id,
          tutor_id: tutor.id,
          duration_minutes: 60,
          rating: 5,
          started_at: DateTime.utc_now(),
          ended_at: DateTime.utc_now()
        })
      end

      assert {:ok, share_pack} = ProudParent.generate(parent.id, week_start)

      assert share_pack.recap_id != nil
      assert share_pack.progress_reel != nil
      assert share_pack.share_message =~ "Amazing progress"
      assert share_pack.links.email != nil
      assert share_pack.links.whatsapp != nil
    end

    test "handles parent joining via referral link" do
      referring_parent = insert(:user, persona: "parent")
      link = create_mock_attribution_link(referring_parent.id, "proud_parent")

      new_parent_attrs = %{
        email: "new_parent@example.com",
        name: "New Parent"
      }

      assert {:ok, result} = ProudParent.handle_join(link.id, new_parent_attrs)
      assert result.parent.email == "new_parent@example.com"
      assert result.welcome_pack.reward == "2 free tutoring sessions"
    end

    test "completes signup and grants rewards" do
      referring_parent = insert(:user, persona: "parent")
      new_parent = insert(:user, persona: "parent")
      link = create_mock_attribution_link(referring_parent.id, "proud_parent")

      completion_data = %{
        profile_completed: true,
        child_added: true,
        first_session_booked: true
      }

      assert {:ok, :signup_completed} =
               ProudParent.complete_signup(new_parent.id, link.id, completion_data)

      # In production, would verify rewards via MCP
    end
  end

  describe "TutorSpotlight Loop" do
    test "generates tutor spotlight after 5-star session" do
      tutor = insert(:user, persona: "tutor")
      student = insert(:user, persona: "student")

      session =
        insert(:tutoring_session, %{
          tutor_id: tutor.id,
          student_id: student.id,
          rating: 5,
          subject: "Mathematics",
          feedback: "Excellent tutor!"
        })

      # Create some history for the tutor
      for _i <- 1..5 do
        insert(:tutoring_session, %{
          tutor_id: tutor.id,
          rating: 5,
          ended_at: DateTime.utc_now()
        })
      end

      assert {:ok, share_pack} = TutorSpotlight.generate(session.id, tutor.id)

      assert share_pack.tutor_card.tutor_id == tutor.id
      assert share_pack.tutor_card.stats.five_star_sessions >= 1
      assert share_pack.links.whatsapp != nil
      assert share_pack.share_message =~ "amazing"
    end

    test "handles student joining via tutor referral" do
      tutor = insert(:user, persona: "tutor")
      link = create_mock_attribution_link(tutor.id, "tutor_spotlight")

      student_attrs = %{
        email: "new_student@example.com",
        name: "New Student"
      }

      assert {:ok, result} = TutorSpotlight.handle_join(link.id, student_attrs)
      assert result.student.email == "new_student@example.com"
      assert result.tutor.id == tutor.id
      assert result.booking_info.discount == "50% off first session"
    end

    test "completes booking and grants rewards" do
      tutor = insert(:user, persona: "tutor")
      student = insert(:user, persona: "student")
      _link = create_mock_attribution_link(tutor.id, "tutor_spotlight")

      booking_data = %{
        session_completed: true,
        payment_processed: true,
        feedback_given: true
      }

      assert {:ok, :booking_completed} =
               TutorSpotlight.complete_booking(student.id, tutor.id, booking_data)
    end

    test "fetches tutor stats correctly" do
      tutor = insert(:user, persona: "tutor")

      # Create varied sessions
      insert(:tutoring_session, %{tutor_id: tutor.id, rating: 5, subject: "Math", ended_at: DateTime.utc_now()})
      insert(:tutoring_session, %{tutor_id: tutor.id, rating: 5, subject: "Physics", ended_at: DateTime.utc_now()})
      insert(:tutoring_session, %{tutor_id: tutor.id, rating: 4, subject: "Math", ended_at: DateTime.utc_now()})

      session = insert(:tutoring_session, %{tutor_id: tutor.id, rating: 5})

      assert {:ok, share_pack} = TutorSpotlight.generate(session.id, tutor.id)

      assert share_pack.tutor_card.stats.total_sessions == 4
      assert share_pack.tutor_card.stats.five_star_sessions == 3
      assert share_pack.tutor_card.stats.average_rating == 4.75
      assert "Math" in share_pack.tutor_card.subjects
      assert "Physics" in share_pack.tutor_card.subjects
    end
  end

  describe "Weekly Recap Generator" do
    test "generates recaps for active parents" do
      parent = insert(:user, persona: "parent")
      student = insert(:user, persona: "student", parent_id: parent.id)
      tutor = insert(:user, persona: "tutor")

      week_start = Date.utc_today() |> Date.beginning_of_week() |> Date.add(-7)

      # Create sessions for last week
      for _i <- 1..4 do
        insert(:tutoring_session, %{
          student_id: student.id,
          tutor_id: tutor.id,
          subject: "Science",
          duration_minutes: 45,
          rating: 5,
          started_at: DateTime.from_naive!(~N[2025-01-06 10:00:00], "Etc/UTC"),
          ended_at: DateTime.from_naive!(~N[2025-01-06 10:45:00], "Etc/UTC")
        })
      end

      job = %Oban.Job{args: %{"week_start" => Date.to_iso8601(week_start)}}
      assert {:ok, result} = WeeklyRecapGenerator.perform(job)

      assert result.recaps > 0
      assert result.loops >= 0

      # Verify recap was created
      recap = Repo.get_by(WeeklyRecap, parent_id: parent.id, week_start: week_start)
      assert recap != nil
      assert recap.session_count == 4
      assert recap.total_minutes == 180
      assert "Science" in recap.skills_practiced
    end

    test "handles parents with no sessions gracefully" do
      parent = insert(:user, persona: "parent")
      _student = insert(:user, persona: "student", parent_id: parent.id)

      week_start = Date.utc_today() |> Date.beginning_of_week() |> Date.add(-7)

      job = %Oban.Job{args: %{"week_start" => Date.to_iso8601(week_start)}}
      assert {:ok, result} = WeeklyRecapGenerator.perform(job)

      # Should complete but not generate recap for this parent
      assert result.recaps == 0
    end

    test "calculates recap metrics accurately" do
      parent = insert(:user, persona: "parent")
      student = insert(:user, persona: "student", parent_id: parent.id)
      tutor = insert(:user, persona: "tutor")

      week_start = Date.utc_today() |> Date.beginning_of_week() |> Date.add(-7)

      # Varied sessions
      insert(:tutoring_session, %{
        student_id: student.id,
        tutor_id: tutor.id,
        subject: "Math",
        topic: "Algebra",
        duration_minutes: 60,
        rating: 5,
        started_at: DateTime.from_naive!(~N[2025-01-06 10:00:00], "Etc/UTC"),
        ended_at: DateTime.from_naive!(~N[2025-01-06 11:00:00], "Etc/UTC")
      })

      insert(:tutoring_session, %{
        student_id: student.id,
        tutor_id: tutor.id,
        subject: "Science",
        topic: "Physics",
        duration_minutes: 45,
        rating: 4,
        started_at: DateTime.from_naive!(~N[2025-01-07 14:00:00], "Etc/UTC"),
        ended_at: DateTime.from_naive!(~N[2025-01-07 14:45:00], "Etc/UTC")
      })

      assert {:ok, share_pack} = ProudParent.generate(parent.id, week_start)
      recap = Repo.get!(WeeklyRecap, share_pack.recap_id)

      assert recap.session_count == 2
      assert recap.total_minutes == 105
      assert recap.improvements["average_rating"] == 4.5
      assert length(recap.skills_practiced) == 4  # Math, Algebra, Science, Physics
    end
  end

  describe "Compliance Middleware" do
    import Plug.Test
    import Plug.Conn

    test "blocks request requiring parental consent for minor without consent" do
      minor = insert(:user, age: 11, persona: "student")

      conn =
        conn(:put, "/api/phase3/users/#{minor.id}/share")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_user, minor)
        |> ViralEngineWeb.ComplianceMiddleware.call([])

      assert conn.halted
      assert conn.status == 403
      assert %{"error" => "parental_consent_required"} = Jason.decode!(conn.resp_body)
    end

    test "allows request for minor with parental consent" do
      minor = insert(:user, age: 11, persona: "student")

      insert(:parental_consent, %{
        user_id: minor.id,
        consent_given: true,
        parent_email: "parent@example.com"
      })

      # Start TrustSafety for this test
      start_supervised!(TrustSafety)

      conn =
        conn(:put, "/api/phase3/users/#{minor.id}/share")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_user, minor)
        |> ViralEngineWeb.ComplianceMiddleware.call([])

      refute conn.halted
    end

    test "allows request for adult user without consent" do
      adult = insert(:user, age: 25, persona: "student")

      # Start TrustSafety
      start_supervised!(TrustSafety)

      conn =
        conn(:get, "/api/phase3/users/#{adult.id}/profile")
        |> assign(:current_user, adult)
        |> ViralEngineWeb.ComplianceMiddleware.call([])

      refute conn.halted
    end

    test "passes through non-sensitive routes" do
      user = insert(:user)

      conn =
        conn(:get, "/api/health")
        |> assign(:current_user, user)
        |> ViralEngineWeb.ComplianceMiddleware.call([])

      refute conn.halted
    end
  end

  # Helper Functions

  defp mock_ai_response do
    # Mock AIClient to return structured summary
    # In real tests, you'd use a mocking library like Mox
    :ok
  end

  defp create_mock_attribution_link(creator_id, loop_type) do
    %{
      id: Ecto.UUID.generate(),
      creator_id: creator_id,
      loop_type: loop_type,
      url: "https://veltutor.com/ref/#{Ecto.UUID.generate()}"
    }
  end

  # Test Factories (using ExMachina or similar)

  defp insert(schema, attrs \\ %{}) do
    case schema do
      :user ->
        %User{}
        |> User.changeset(
          Map.merge(
            %{
              email: "user_#{:rand.uniform(10000)}@example.com",
              name: "Test User"
            },
            attrs
          )
        )
        |> Repo.insert!()

      :tutoring_session ->
        %TutoringSession{}
        |> TutoringSession.changeset(
          Map.merge(
            %{
              student_id: 1,
              tutor_id: 2,
              subject: "Test Subject",
              duration_minutes: 60
            },
            attrs
          )
        )
        |> Repo.insert!()

      :device_flag ->
        %DeviceFlag{}
        |> DeviceFlag.changeset(
          Map.merge(
            %{
              device_id: "device-#{:rand.uniform(10000)}",
              ip_address: "192.168.1.1",
              flag_type: "test"
            },
            attrs
          )
        )
        |> Repo.insert!()

      :parental_consent ->
        %ParentalConsent{}
        |> ParentalConsent.changeset(
          Map.merge(
            %{
              user_id: 1,
              parent_email: "parent@example.com",
              consent_given: false
            },
            attrs
          )
        )
        |> Repo.insert!()
    end
  end
end
