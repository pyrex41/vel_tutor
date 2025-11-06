defmodule ViralEngine.ChallengeSession do
  @moduledoc """
  Schema for challenge sessions tracking user participation.

  Challenge sessions track individual user attempts at challenge decks,
  including scores, completion status, and attribution links.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "challenge_sessions" do
    field(:user_id, :integer)
    field(:referrer_id, :integer)
    field(:score, :integer)
    field(:completed_at, :utc_datetime)

    belongs_to(:deck, ViralEngine.ChallengeDeck)
    belongs_to(:link, ViralEngine.AttributionLink)

    timestamps()
  end

  def changeset(challenge_session, attrs) do
    challenge_session
    |> cast(attrs, [:user_id, :referrer_id, :score, :completed_at, :deck_id, :link_id])
    |> validate_required([:user_id, :deck_id])
  end
end
