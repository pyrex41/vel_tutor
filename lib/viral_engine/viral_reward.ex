defmodule ViralEngine.ViralReward do
  @moduledoc """
  Schema for tracking viral loop rewards granted to users.

  Different from UserReward - these are automatically granted rewards
  from viral loop participation, not purchased from the rewards shop.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_rewards" do
    field(:user_id, :integer)
    field(:reward_type, :string)
    field(:amount, :integer)
    field(:source_loop_id, :string)
    field(:source_event_id, :string)
    field(:redeemed, :boolean, default: false)
    field(:redeemed_at, :utc_datetime)
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(viral_reward, attrs) do
    viral_reward
    |> cast(attrs, [
      :user_id,
      :reward_type,
      :amount,
      :source_loop_id,
      :source_event_id,
      :redeemed,
      :redeemed_at,
      :expires_at
    ])
    |> validate_required([:user_id, :reward_type, :amount])
  end
end
