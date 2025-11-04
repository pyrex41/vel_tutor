defmodule ViralEngine.BuddyChallenge do
  @moduledoc """
  Schema for student-to-student challenges.

  Tracks challenge invitations, acceptances, and completions for viral growth.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "buddy_challenges" do
    field(:challenger_id, :integer)  # User who creates the challenge
    field(:challenged_user_id, :integer)  # Invited user (null if by link)
    field(:challenged_email, :string)  # Email for external invites
    field(:session_id, :integer)  # Original practice session
    field(:subject, :string)
    field(:challenger_score, :integer)
    field(:challenged_score, :integer)  # Score of challenged user's attempt

    field(:challenge_token, :string)  # Signed token for deep links
    field(:status, :string, default: "pending")  # pending, accepted, completed, expired

    field(:expires_at, :utc_datetime)
    field(:accepted_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    field(:reward_granted, :boolean, default: false)
    field(:winner_id, :integer)  # User who won (highest score)

    field(:share_method, :string)  # link, email, web_share
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [
      :challenger_id,
      :challenged_user_id,
      :challenged_email,
      :session_id,
      :subject,
      :challenger_score,
      :challenged_score,
      :challenge_token,
      :status,
      :expires_at,
      :accepted_at,
      :completed_at,
      :reward_granted,
      :winner_id,
      :share_method,
      :metadata
    ])
    |> validate_required([:challenger_id, :session_id, :subject, :challenger_score])
    |> validate_inclusion(:status, ["pending", "accepted", "completed", "expired", "declined"])
    |> validate_inclusion(:share_method, ["link", "email", "web_share", "copy_link"])
    |> validate_number(:challenger_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:challenged_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:challenge_token)
  end

  @doc """
  Checks if a challenge has expired.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Determines the winner of a completed challenge.
  """
  def determine_winner(%__MODULE__{status: "completed"} = challenge) do
    cond do
      challenge.challenged_score > challenge.challenger_score -> challenge.challenged_user_id
      challenge.challenged_score < challenge.challenger_score -> challenge.challenger_id
      true -> nil  # Tie
    end
  end

  def determine_winner(_), do: nil
end
