defmodule ViralEngine.ChallengeDeck do
  @moduledoc """
  Schema for challenge decks used in viral loops.

  Challenge decks contain questions and metadata for buddy challenges
  and other competitive learning activities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "challenge_decks" do
    field(:type, :string)
    field(:skill, :string)
    # Array of question objects
    field(:questions, {:array, :map})
    field(:participant_count, :integer, default: 0)
    field(:completion_count, :integer, default: 0)
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(challenge_deck, attrs) do
    challenge_deck
    |> cast(attrs, [:type, :skill, :questions, :participant_count, :completion_count, :expires_at])
    |> validate_required([:type])
  end
end
