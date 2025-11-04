defmodule ViralEngine.RallyParticipant do
  @moduledoc """
  Schema for tracking rally participants and their scores.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "rally_participants" do
    field(:rally_id, :integer)
    field(:user_id, :integer)
    field(:assessment_id, :integer)  # Link to diagnostic assessment
    field(:score, :integer)
    field(:rank, :integer)
    field(:joined_via, :string)  # creator, invite_link, direct_join
    field(:is_creator, :boolean, default: false)

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :rally_id,
      :user_id,
      :assessment_id,
      :score,
      :rank,
      :joined_via,
      :is_creator
    ])
    |> validate_required([:rally_id, :user_id])
    |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:joined_via, ["creator", "invite_link", "direct_join"])
    |> unique_constraint([:rally_id, :user_id])
  end
end
