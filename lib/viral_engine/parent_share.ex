defmodule ViralEngine.ParentShare do
  @moduledoc """
  Schema for tracking parent progress sharing (Proud Parent Loop).

  COPPA-compliant parent sharing with privacy-safe progress cards and referral tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "parent_shares" do
    field(:student_id, :integer)  # Student whose progress is being shared
    field(:parent_email, :string)  # Parent email (encrypted if stored)
    field(:share_token, :string)  # Unique share token
    field(:share_type, :string)  # achievement, milestone, weekly_progress, report_card

    field(:progress_data, :map, default: %{})  # Privacy-safe progress data
    field(:metadata, :map, default: %{})

    field(:viewed, :boolean, default: false)
    field(:viewed_at, :utc_datetime)
    field(:shared_at, :utc_datetime)

    field(:referral_used, :boolean, default: false)
    field(:referral_reward_granted, :boolean, default: false)

    field(:expires_at, :utc_datetime)
    field(:status, :string, default: "pending")  # pending, viewed, expired

    timestamps()
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [
      :student_id,
      :parent_email,
      :share_token,
      :share_type,
      :progress_data,
      :metadata,
      :viewed,
      :viewed_at,
      :shared_at,
      :referral_used,
      :referral_reward_granted,
      :expires_at,
      :status
    ])
    |> validate_required([:student_id, :share_token, :share_type])
    |> validate_inclusion(:share_type, ["achievement", "milestone", "weekly_progress", "report_card"])
    |> validate_inclusion(:status, ["pending", "viewed", "expired"])
    |> validate_format(:parent_email, ~r/@/)
    |> unique_constraint(:share_token)
  end

  @doc """
  Checks if a share has expired.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end
