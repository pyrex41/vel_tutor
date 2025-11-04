defmodule ViralEngine.PracticeContextTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.{PracticeContext, PracticeSession, PracticeStep, PracticeAnswer}

  describe "create_session/1" do
    test "creates a practice session with valid attributes" do
      attrs = %{
        user_id: 1,
        session_type: "practice_test",
        subject: "math",
        total_steps: 5
      }

      assert {:ok, %PracticeSession{} = session} = PracticeContext.create_session(attrs)
      assert session.user_id == 1
      assert session.session_type == "practice_test"
      assert session.subject == "math"
      assert session.total_steps == 5
      assert session.current_step == 1
      assert session.timer_seconds == 0
      assert session.paused == false
      assert session.completed == false
    end

    test "validates required fields" do
      attrs = %{user_id: 1}

      assert {:error, changeset} = PracticeContext.create_session(attrs)
      assert %{session_type: ["can't be blank"], subject: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates session_type enum" do
      attrs = %{
        user_id: 1,
        session_type: "invalid_type",
        subject: "math"
      }

      assert {:error, changeset} = PracticeContext.create_session(attrs)
      assert %{session_type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "get_session/1 and get_user_session/2" do
    test "gets a session by ID with preloaded associations" do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "flashcard",
          subject: "science",
          total_steps: 3
        })

      fetched_session = PracticeContext.get_session(session.id)
      assert fetched_session.id == session.id
      assert Ecto.assoc_loaded?(fetched_session.steps)
      assert Ecto.assoc_loaded?(fetched_session.answers)
    end

    test "gets a session for a specific user" do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 123,
          session_type: "diagnostic",
          subject: "english"
        })

      assert fetched = PracticeContext.get_user_session(session.id, 123)
      assert fetched.id == session.id
      assert is_nil(PracticeContext.get_user_session(session.id, 999))
    end
  end

  describe "update_session/2 and update_progress/2" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "practice_test",
          subject: "math",
          total_steps: 5
        })

      %{session: session}
    end

    test "updates session attributes", %{session: session} do
      {:ok, updated} = PracticeContext.update_session(session, %{current_step: 3, timer_seconds: 150})
      assert updated.current_step == 3
      assert updated.timer_seconds == 150
    end

    test "updates progress by session ID", %{session: session} do
      {:ok, updated} =
        PracticeContext.update_progress(session.id, %{
          current_step: 2,
          timer_seconds: 45,
          paused: true
        })

      assert updated.current_step == 2
      assert updated.timer_seconds == 45
      assert updated.paused == true
    end

    test "returns error for non-existent session" do
      assert {:error, :not_found} = PracticeContext.update_progress(99999, %{current_step: 1})
    end
  end

  describe "complete_session/1" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "practice_test",
          subject: "math",
          total_steps: 3
        })

      {:ok, steps} =
        PracticeContext.create_steps(session.id, [
          {1, %{title: "Q1", content: "Question 1", question_type: "multiple_choice", correct_answer: "A"}},
          {2, %{title: "Q2", content: "Question 2", question_type: "true_false", correct_answer: "true"}},
          {3, %{title: "Q3", content: "Question 3", question_type: "open_ended", correct_answer: "answer"}}
        ])

      %{session: session, steps: steps}
    end

    test "completes session and calculates score", %{session: session, steps: steps} do
      # Record 2 correct answers
      PracticeContext.record_answer(%{
        practice_session_id: session.id,
        practice_step_id: Enum.at(steps, 0).id,
        user_answer: "A",
        is_correct: true
      })

      PracticeContext.record_answer(%{
        practice_session_id: session.id,
        practice_step_id: Enum.at(steps, 1).id,
        user_answer: "true",
        is_correct: true
      })

      # 1 incorrect answer
      PracticeContext.record_answer(%{
        practice_session_id: session.id,
        practice_step_id: Enum.at(steps, 2).id,
        user_answer: "wrong",
        is_correct: false
      })

      {:ok, completed} = PracticeContext.complete_session(session.id)

      assert completed.completed == true
      # 2 out of 3 correct = 67%
      assert completed.score == 67
    end
  end

  describe "create_step/1 and create_steps/2" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "flashcard",
          subject: "vocabulary"
        })

      %{session: session}
    end

    test "creates a single step", %{session: session} do
      attrs = %{
        practice_session_id: session.id,
        step_number: 1,
        title: "Question 1",
        content: "What is 2+2?",
        question_type: "multiple_choice",
        correct_answer: "4",
        options: ["2", "3", "4", "5"]
      }

      assert {:ok, %PracticeStep{} = step} = PracticeContext.create_step(attrs)
      assert step.step_number == 1
      assert step.title == "Question 1"
      assert step.question_type == "multiple_choice"
      assert step.options == ["2", "3", "4", "5"]
    end

    test "creates multiple steps", %{session: session} do
      steps_data = [
        {1, %{title: "Q1", content: "Question 1", question_type: "multiple_choice", correct_answer: "A"}},
        {2, %{title: "Q2", content: "Question 2", question_type: "true_false", correct_answer: "true"}},
        {3, %{title: "Q3", content: "Question 3", question_type: "open_ended", correct_answer: "answer"}}
      ]

      assert {:ok, steps} = PracticeContext.create_steps(session.id, steps_data)
      assert length(steps) == 3
      assert Enum.at(steps, 0).step_number == 1
      assert Enum.at(steps, 2).step_number == 3
    end
  end

  describe "list_session_steps/1 and get_step/2" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "practice_test",
          subject: "math"
        })

      {:ok, steps} =
        PracticeContext.create_steps(session.id, [
          {1, %{title: "Q1", content: "Question 1", question_type: "multiple_choice", correct_answer: "A"}},
          {2, %{title: "Q2", content: "Question 2", question_type: "true_false", correct_answer: "true"}}
        ])

      %{session: session, steps: steps}
    end

    test "lists all steps for a session in order", %{session: session} do
      steps = PracticeContext.list_session_steps(session.id)
      assert length(steps) == 2
      assert Enum.at(steps, 0).step_number == 1
      assert Enum.at(steps, 1).step_number == 2
    end

    test "gets a specific step by session and step number", %{session: session} do
      step = PracticeContext.get_step(session.id, 2)
      assert step.step_number == 2
      assert step.title == "Q2"
    end

    test "returns nil for non-existent step", %{session: session} do
      assert is_nil(PracticeContext.get_step(session.id, 999))
    end
  end

  describe "complete_step/2" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "practice_test",
          subject: "math"
        })

      {:ok, _steps} =
        PracticeContext.create_steps(session.id, [
          {1, %{title: "Q1", content: "Question 1", question_type: "multiple_choice", correct_answer: "A"}}
        ])

      %{session: session}
    end

    test "marks a step as completed", %{session: session} do
      step = PracticeContext.get_step(session.id, 1)
      assert step.completed == false

      {:ok, updated} = PracticeContext.complete_step(session.id, 1)
      assert updated.completed == true
    end
  end

  describe "record_answer/1 and validate_and_record_answer/3" do
    setup do
      {:ok, session} =
        PracticeContext.create_session(%{
          user_id: 1,
          session_type: "practice_test",
          subject: "math"
        })

      {:ok, steps} =
        PracticeContext.create_steps(session.id, [
          {1, %{title: "Multiple Choice", content: "What is 2+2?", question_type: "multiple_choice", correct_answer: "4"}},
          {2, %{title: "True/False", content: "Is the sky blue?", question_type: "true_false", correct_answer: "true"}},
          {3, %{title: "Open Ended", content: "Explain gravity", question_type: "open_ended", correct_answer: "force,mass,attraction"}}
        ])

      %{session: session, steps: steps}
    end

    test "records an answer with validation - correct multiple choice", %{session: session} do
      {:ok, answer} = PracticeContext.validate_and_record_answer(session.id, 1, "4")
      assert answer.is_correct == true
      assert answer.feedback =~ "Correct"
    end

    test "records an answer with validation - incorrect multiple choice", %{session: session} do
      {:ok, answer} = PracticeContext.validate_and_record_answer(session.id, 1, "5")
      assert answer.is_correct == false
      assert answer.feedback =~ "Not quite right"
    end

    test "validates true/false questions", %{session: session} do
      {:ok, answer} = PracticeContext.validate_and_record_answer(session.id, 2, "true")
      assert answer.is_correct == true

      {:ok, wrong_answer} = PracticeContext.validate_and_record_answer(session.id, 2, "false")
      assert wrong_answer.is_correct == false
    end

    test "validates open-ended questions with keyword matching", %{session: session} do
      {:ok, answer} = PracticeContext.validate_and_record_answer(session.id, 3, "It's a force that attracts masses")
      assert answer.is_correct == true

      {:ok, wrong_answer} = PracticeContext.validate_and_record_answer(session.id, 3, "I don't know")
      assert wrong_answer.is_correct == false
    end
  end

  describe "list_user_active_sessions/1 and list_user_completed_sessions/2" do
    setup do
      user_id = 42

      {:ok, active1} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "practice_test",
          subject: "math"
        })

      {:ok, active2} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "flashcard",
          subject: "science"
        })

      {:ok, completed} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "diagnostic",
          subject: "english",
          completed: true
        })

      %{user_id: user_id, active1: active1, active2: active2, completed: completed}
    end

    test "lists active sessions for a user", %{user_id: user_id} do
      active_sessions = PracticeContext.list_user_active_sessions(user_id)
      assert length(active_sessions) == 2
      assert Enum.all?(active_sessions, &(&1.completed == false))
    end

    test "lists completed sessions for a user", %{user_id: user_id} do
      completed_sessions = PracticeContext.list_user_completed_sessions(user_id)
      assert length(completed_sessions) == 1
      assert Enum.all?(completed_sessions, &(&1.completed == true))
    end
  end

  describe "get_user_stats/1" do
    test "calculates user statistics" do
      user_id = 100

      # Create 3 sessions - 2 completed, 1 active
      {:ok, session1} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "practice_test",
          subject: "math",
          completed: true,
          score: 80,
          timer_seconds: 300
        })

      {:ok, session2} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "flashcard",
          subject: "science",
          completed: true,
          score: 90,
          timer_seconds: 450
        })

      {:ok, _session3} =
        PracticeContext.create_session(%{
          user_id: user_id,
          session_type: "diagnostic",
          subject: "english",
          timer_seconds: 200
        })

      stats = PracticeContext.get_user_stats(user_id)

      assert stats.total_sessions == 3
      assert stats.completed_sessions == 2
      assert stats.average_score == 85.0
      assert stats.total_time_seconds == 950
    end
  end
end
