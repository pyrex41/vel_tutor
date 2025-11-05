defmodule ViralEngine.ActivitiesTest do
  use ViralEngine.DataCase, async: true

  alias ViralEngine.Activities
  alias ViralEngine.Activities.{Event, Reaction}
  alias ViralEngine.Accounts.User

  defp create_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      name: "Test User"
    }

    %User{}
    |> User.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  describe "create_event/1" do
    test "creates an activity event with valid attributes" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        event_type: "streak_completed",
        data: %{"streak_count" => 7},
        visibility: "public"
      }

      assert {:ok, %Event{} = event} = Activities.create_event(attrs)
      assert event.user_id == user.id
      assert event.event_type == "streak_completed"
      assert event.data == %{"streak_count" => 7}
      assert event.visibility == "public"
      assert event.reactions_count == 0
    end

    test "creates event with default visibility" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        event_type: "practice_completed"
      }

      assert {:ok, %Event{} = event} = Activities.create_event(attrs)
      assert event.visibility == "public"
    end

    test "creates event with subject_id" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        event_type: "high_score",
        subject_id: 123,
        data: %{"score" => 95}
      }

      assert {:ok, %Event{} = event} = Activities.create_event(attrs)
      assert event.subject_id == 123
    end

    test "fails without required user_id" do
      attrs = %{
        event_type: "practice_completed"
      }

      assert {:error, changeset} = Activities.create_event(attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails without required event_type" do
      user = create_user()

      attrs = %{
        user_id: user.id
      }

      assert {:error, changeset} = Activities.create_event(attrs)
      assert %{event_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates visibility inclusion" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        event_type: "test",
        visibility: "invalid"
      }

      assert {:error, changeset} = Activities.create_event(attrs)
      assert %{visibility: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "list_recent_activities/1" do
    test "returns recent activities ordered by inserted_at desc" do
      user = create_user()

      # Create multiple events
      {:ok, event1} = Activities.create_event(%{
        user_id: user.id,
        event_type: "practice_completed"
      })

      {:ok, event2} = Activities.create_event(%{
        user_id: user.id,
        event_type: "streak_completed"
      })

      {:ok, event3} = Activities.create_event(%{
        user_id: user.id,
        event_type: "badge_earned"
      })

      activities = Activities.list_recent_activities()

      assert length(activities) == 3
      # Verify all events are present
      activity_ids = Enum.map(activities, & &1.id)
      assert event1.id in activity_ids
      assert event2.id in activity_ids
      assert event3.id in activity_ids
      # Verify descending order by timestamp
      timestamps = Enum.map(activities, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, NaiveDateTime})
    end

    test "respects limit option" do
      user = create_user()

      # Create 10 events
      for _ <- 1..10 do
        Activities.create_event(%{
          user_id: user.id,
          event_type: "practice_completed"
        })
      end

      activities = Activities.list_recent_activities(limit: 5)

      assert length(activities) == 5
    end

    test "defaults to limit of 50" do
      user = create_user()

      # Create 60 events
      for _ <- 1..60 do
        Activities.create_event(%{
          user_id: user.id,
          event_type: "practice_completed"
        })
      end

      activities = Activities.list_recent_activities()

      assert length(activities) == 50
    end

    test "preloads user association" do
      user = create_user()

      {:ok, _event} = Activities.create_event(%{
        user_id: user.id,
        event_type: "practice_completed"
      })

      [activity] = Activities.list_recent_activities()

      assert %Ecto.Association.NotLoaded{} != activity.user
      assert activity.user.id == user.id
    end
  end

  describe "list_subject_activities/2" do
    test "returns activities for specific subject" do
      user = create_user()
      subject_id = 123

      {:ok, event1} = Activities.create_event(%{
        user_id: user.id,
        event_type: "high_score",
        subject_id: subject_id
      })

      {:ok, _event2} = Activities.create_event(%{
        user_id: user.id,
        event_type: "practice_completed",
        subject_id: 456  # Different subject
      })

      activities = Activities.list_subject_activities(subject_id)

      assert length(activities) == 1
      assert hd(activities).id == event1.id
    end

    test "orders by inserted_at desc" do
      user = create_user()
      subject_id = 123

      {:ok, event1} = Activities.create_event(%{
        user_id: user.id,
        event_type: "practice_completed",
        subject_id: subject_id
      })

      {:ok, event2} = Activities.create_event(%{
        user_id: user.id,
        event_type: "high_score",
        subject_id: subject_id
      })

      activities = Activities.list_subject_activities(subject_id)

      assert length(activities) == 2
      # Most recent first - event2 should have timestamp >= event1
      [first, second] = activities
      assert NaiveDateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]
      # Verify both events are in the list
      activity_ids = Enum.map(activities, & &1.id)
      assert event1.id in activity_ids
      assert event2.id in activity_ids
    end

    test "respects limit option" do
      user = create_user()
      subject_id = 123

      # Create 10 events
      for _ <- 1..10 do
        Activities.create_event(%{
          user_id: user.id,
          event_type: "practice_completed",
          subject_id: subject_id
        })
      end

      activities = Activities.list_subject_activities(subject_id, limit: 3)

      assert length(activities) == 3
    end
  end

  describe "add_reaction/3" do
    test "adds reaction to activity" do
      user1 = create_user()
      user2 = create_user()

      {:ok, event} = Activities.create_event(%{
        user_id: user1.id,
        event_type: "streak_completed"
      })

      assert {:ok, %Reaction{} = reaction} = Activities.add_reaction(event.id, user2.id, "👍")
      assert reaction.activity_event_id == event.id
      assert reaction.user_id == user2.id
      assert reaction.reaction == "👍"
    end

    test "increments reactions_count on event" do
      user1 = create_user()
      user2 = create_user()

      {:ok, event} = Activities.create_event(%{
        user_id: user1.id,
        event_type: "streak_completed"
      })

      assert event.reactions_count == 0

      {:ok, _reaction} = Activities.add_reaction(event.id, user2.id, "👍")

      # Reload event from database
      updated_event = Repo.get!(Event, event.id)
      assert updated_event.reactions_count == 1
    end

    test "allows multiple reactions from different users" do
      user1 = create_user()
      user2 = create_user()
      user3 = create_user()

      {:ok, event} = Activities.create_event(%{
        user_id: user1.id,
        event_type: "streak_completed"
      })

      {:ok, _reaction1} = Activities.add_reaction(event.id, user2.id, "👍")
      {:ok, _reaction2} = Activities.add_reaction(event.id, user3.id, "🔥")

      updated_event = Repo.get!(Event, event.id)
      assert updated_event.reactions_count == 2
    end

    test "prevents duplicate reactions from same user" do
      user1 = create_user()
      user2 = create_user()

      {:ok, event} = Activities.create_event(%{
        user_id: user1.id,
        event_type: "streak_completed"
      })

      {:ok, _reaction1} = Activities.add_reaction(event.id, user2.id, "👍")
      {:error, changeset} = Activities.add_reaction(event.id, user2.id, "🔥")

      assert "has already been taken" in errors_on(changeset).activity_event_id
    end
  end
end
