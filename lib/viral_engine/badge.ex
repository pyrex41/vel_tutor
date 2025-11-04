defmodule ViralEngine.Badge do
  @moduledoc """
  Schema for defining available badges and achievements.

  Badges are earned by completing specific milestones and achievements.
  Each badge has criteria that determine when it should be unlocked.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "badges" do
    field(:name, :string)
    field(:description, :string)
    field(:badge_type, :string)  # milestone, streak, social, skill, special
    field(:category, :string)    # practice, diagnostic, social, achievement

    field(:icon, :string)        # Emoji or icon identifier
    field(:color, :string)       # Badge color theme
    field(:rarity, :string)      # common, rare, epic, legendary

    field(:criteria, :map)       # Achievement criteria as structured data
    field(:reward_xp, :integer, default: 0)
    field(:metadata, :map, default: %{})

    field(:is_active, :boolean, default: true)
    field(:is_secret, :boolean, default: false)  # Hidden until unlocked
    field(:order, :integer, default: 0)           # Display order

    timestamps()
  end

  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [
      :name,
      :description,
      :badge_type,
      :category,
      :icon,
      :color,
      :rarity,
      :criteria,
      :reward_xp,
      :metadata,
      :is_active,
      :is_secret,
      :order
    ])
    |> validate_required([:name, :description, :badge_type, :category, :icon])
    |> validate_inclusion(:badge_type, ["milestone", "streak", "social", "skill", "special"])
    |> validate_inclusion(:category, ["practice", "diagnostic", "social", "achievement"])
    |> validate_inclusion(:rarity, ["common", "rare", "epic", "legendary"])
    |> unique_constraint(:name)
  end

  @doc """
  Returns default badge definitions for seeding.
  """
  def default_badges do
    [
      # Practice milestones
      %{
        name: "First Steps",
        description: "Complete your first practice session",
        badge_type: "milestone",
        category: "practice",
        icon: "👣",
        color: "blue",
        rarity: "common",
        criteria: %{type: "practice_sessions_completed", threshold: 1},
        reward_xp: 10,
        order: 1
      },
      %{
        name: "Practice Warrior",
        description: "Complete 10 practice sessions",
        badge_type: "milestone",
        category: "practice",
        icon: "⚔️",
        color: "green",
        rarity: "common",
        criteria: %{type: "practice_sessions_completed", threshold: 10},
        reward_xp: 50,
        order: 2
      },
      %{
        name: "Century Club",
        description: "Complete 100 practice sessions",
        badge_type: "milestone",
        category: "practice",
        icon: "💯",
        color: "purple",
        rarity: "rare",
        criteria: %{type: "practice_sessions_completed", threshold: 100},
        reward_xp: 250,
        order: 3
      },

      # Streak badges
      %{
        name: "On a Roll",
        description: "Maintain a 3-day practice streak",
        badge_type: "streak",
        category: "achievement",
        icon: "🔥",
        color: "orange",
        rarity: "common",
        criteria: %{type: "streak_reached", threshold: 3},
        reward_xp: 30,
        order: 10
      },
      %{
        name: "Streak Master",
        description: "Maintain a 7-day practice streak",
        badge_type: "streak",
        category: "achievement",
        icon: "🔥🔥",
        color: "red",
        rarity: "rare",
        criteria: %{type: "streak_reached", threshold: 7},
        reward_xp: 100,
        order: 11
      },
      %{
        name: "Unstoppable",
        description: "Maintain a 30-day practice streak",
        badge_type: "streak",
        category: "achievement",
        icon: "🔥🔥🔥",
        color: "red",
        rarity: "epic",
        criteria: %{type: "streak_reached", threshold: 30},
        reward_xp: 500,
        order: 12
      },

      # Skill mastery
      %{
        name: "Perfect Score",
        description: "Get 100% on any assessment",
        badge_type: "skill",
        category: "diagnostic",
        icon: "⭐",
        color: "yellow",
        rarity: "rare",
        criteria: %{type: "perfect_score", threshold: 100},
        reward_xp: 150,
        order: 20
      },
      %{
        name: "Quick Learner",
        description: "Complete 5 assessments with 90%+ scores",
        badge_type: "skill",
        category: "diagnostic",
        icon: "🚀",
        color: "blue",
        rarity: "rare",
        criteria: %{type: "high_scores", threshold: 5, min_score: 90},
        reward_xp: 200,
        order: 21
      },

      # Social badges
      %{
        name: "Challenger",
        description: "Send your first buddy challenge",
        badge_type: "social",
        category: "social",
        icon: "🎯",
        color: "purple",
        rarity: "common",
        criteria: %{type: "challenges_sent", threshold: 1},
        reward_xp: 25,
        order: 30
      },
      %{
        name: "Rally Leader",
        description: "Create a results rally",
        badge_type: "social",
        category: "social",
        icon: "📣",
        color: "orange",
        rarity: "common",
        criteria: %{type: "rallies_created", threshold: 1},
        reward_xp: 50,
        order: 31
      },
      %{
        name: "Social Butterfly",
        description: "Send 10 challenges or join 10 rallies",
        badge_type: "social",
        category: "social",
        icon: "🦋",
        color: "pink",
        rarity: "rare",
        criteria: %{type: "social_interactions", threshold: 10},
        reward_xp: 100,
        order: 32
      },

      # Special achievements
      %{
        name: "Early Bird",
        description: "Complete a practice session before 8 AM",
        badge_type: "special",
        category: "achievement",
        icon: "🌅",
        color: "yellow",
        rarity: "common",
        criteria: %{type: "practice_before_hour", threshold: 8},
        reward_xp: 20,
        order: 40
      },
      %{
        name: "Night Owl",
        description: "Complete a practice session after 10 PM",
        badge_type: "special",
        category: "achievement",
        icon: "🦉",
        color: "indigo",
        rarity: "common",
        criteria: %{type: "practice_after_hour", threshold: 22},
        reward_xp: 20,
        order: 41
      },
      %{
        name: "Comeback Kid",
        description: "Rescue a streak from breaking",
        badge_type: "special",
        category: "achievement",
        icon: "💪",
        color: "green",
        rarity: "rare",
        criteria: %{type: "streak_rescued", threshold: 1},
        reward_xp: 75,
        order: 42
      },
      %{
        name: "Proud Parent",
        description: "Share progress with a parent",
        badge_type: "special",
        category: "social",
        icon: "👨‍👩‍👧‍👦",
        color: "blue",
        rarity: "common",
        criteria: %{type: "parent_shares", threshold: 1},
        reward_xp: 30,
        order: 43
      }
    ]
  end
end
