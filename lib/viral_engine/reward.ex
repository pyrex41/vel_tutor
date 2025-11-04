defmodule ViralEngine.Reward do
  @moduledoc """
  Schema for rewards available in the rewards shop.

  Rewards can be cosmetic items, power-ups, avatars, themes, or special privileges.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "rewards" do
    field(:name, :string)
    field(:description, :string)
    field(:reward_type, :string)  # cosmetic, powerup, avatar, theme, special

    field(:icon, :string)
    field(:image_url, :string)
    field(:rarity, :string, default: "common")

    field(:xp_cost, :integer, default: 0)
    field(:level_required, :integer, default: 1)

    field(:is_active, :boolean, default: true)
    field(:is_limited, :boolean, default: false)
    field(:stock, :integer)  # nil = unlimited
    field(:expires_at, :utc_datetime)

    field(:metadata, :map, default: %{})
    field(:order, :integer, default: 0)

    timestamps()
  end

  def changeset(reward, attrs) do
    reward
    |> cast(attrs, [
      :name,
      :description,
      :reward_type,
      :icon,
      :image_url,
      :rarity,
      :xp_cost,
      :level_required,
      :is_active,
      :is_limited,
      :stock,
      :expires_at,
      :metadata,
      :order
    ])
    |> validate_required([:name, :description, :reward_type, :xp_cost])
    |> validate_inclusion(:reward_type, ["cosmetic", "powerup", "avatar", "theme", "special"])
    |> validate_inclusion(:rarity, ["common", "rare", "epic", "legendary"])
    |> validate_number(:xp_cost, greater_than_or_equal_to: 0)
    |> validate_number(:level_required, greater_than_or_equal_to: 1)
  end

  @doc """
  Returns default rewards for seeding.
  """
  def default_rewards do
    [
      # Cosmetic rewards
      %{
        name: "Gold Star Avatar",
        description: "Show off your excellence with this shiny gold star profile picture",
        reward_type: "cosmetic",
        icon: "⭐",
        rarity: "common",
        xp_cost: 100,
        level_required: 1,
        order: 1
      },
      %{
        name: "Rainbow Theme",
        description: "Make your dashboard colorful with the rainbow color theme",
        reward_type: "theme",
        icon: "🌈",
        rarity: "rare",
        xp_cost: 500,
        level_required: 5,
        order: 2
      },
      %{
        name: "Rocket Avatar",
        description: "Blast off to success with this rocket avatar",
        reward_type: "avatar",
        icon: "🚀",
        rarity: "rare",
        xp_cost: 750,
        level_required: 8,
        order: 3
      },
      %{
        name: "Crown Badge",
        description: "Display your royal status with this crown badge",
        reward_type: "cosmetic",
        icon: "👑",
        rarity: "epic",
        xp_cost: 1500,
        level_required: 15,
        order: 4
      },

      # Powerups
      %{
        name: "2x XP Boost (1 hour)",
        description: "Double your XP earnings for 1 hour",
        reward_type: "powerup",
        icon: "⚡",
        rarity: "common",
        xp_cost: 200,
        level_required: 3,
        metadata: %{duration_minutes: 60, multiplier: 2.0},
        order: 10
      },
      %{
        name: "Streak Shield",
        description: "Protect your streak from breaking once",
        reward_type: "powerup",
        icon: "🛡️",
        rarity: "rare",
        xp_cost: 400,
        level_required: 5,
        metadata: %{uses: 1},
        order: 11
      },
      %{
        name: "Hint Master",
        description: "Get 3 extra hints for assessments",
        reward_type: "powerup",
        icon: "💡",
        rarity: "common",
        xp_cost: 150,
        level_required: 2,
        metadata: %{hints: 3},
        order: 12
      },

      # Special privileges
      %{
        name: "Custom Username",
        description: "Choose your own custom username",
        reward_type: "special",
        icon: "✍️",
        rarity: "epic",
        xp_cost: 1000,
        level_required: 10,
        order: 20
      },
      %{
        name: "VIP Badge",
        description: "Display VIP status on your profile",
        reward_type: "special",
        icon: "💎",
        rarity: "legendary",
        xp_cost: 5000,
        level_required: 25,
        order: 21
      },
      %{
        name: "Early Access Pass",
        description: "Get early access to new features",
        reward_type: "special",
        icon: "🎟️",
        rarity: "legendary",
        xp_cost: 10000,
        level_required: 50,
        order: 22
      }
    ]
  end
end
