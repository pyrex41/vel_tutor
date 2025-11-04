defmodule ViralEngine.PrepPack do
  @moduledoc """
  Schema for next-session preparation packs.

  Prep packs are automatically generated resource bundles that help
  students prepare for their next practice session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "prep_packs" do
    field(:student_id, :integer)
    field(:pack_token, :string)
    field(:pack_name, :string)

    field(:subject, :string)
    field(:grade_level, :integer)
    field(:target_topics, {:array, :string}, default: [])

    field(:pack_type, :string, default: "practice_prep")
    # practice_prep, exam_prep, review_pack, challenge_prep

    field(:resources, :map, default: %{})
    # study_guides, practice_problems, video_links, flashcard_decks

    field(:ai_recommendations, :text)
    field(:estimated_time_minutes, :integer, default: 30)

    field(:status, :string, default: "generated")
    # generated, shared, viewed, completed

    field(:share_count, :integer, default: 0)
    field(:view_count, :integer, default: 0)

    field(:expires_at, :utc_datetime)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(prep_pack, attrs) do
    prep_pack
    |> cast(attrs, [
      :student_id,
      :pack_token,
      :pack_name,
      :subject,
      :grade_level,
      :target_topics,
      :pack_type,
      :resources,
      :ai_recommendations,
      :estimated_time_minutes,
      :status,
      :share_count,
      :view_count,
      :expires_at,
      :metadata
    ])
    |> validate_required([:student_id, :pack_token, :pack_name, :subject])
    |> validate_inclusion(:pack_type, ["practice_prep", "exam_prep", "review_pack", "challenge_prep"])
    |> validate_inclusion(:status, ["generated", "shared", "viewed", "completed"])
    |> unique_constraint(:pack_token)
  end

  @doc """
  Generates a unique pack token.
  """
  def generate_token(student_id, subject) do
    :crypto.hash(:sha256, "#{student_id}-#{subject}-#{System.system_time(:microsecond)}")
    |> Base.url_encode64()
    |> binary_part(0, 32)
  end

  @doc """
  Increments share count.
  """
  def increment_shares(pack) do
    changeset(pack, %{
      share_count: pack.share_count + 1,
      status: "shared"
    })
  end

  @doc """
  Increments view count.
  """
  def increment_views(pack) do
    new_status = if pack.status == "generated", do: "viewed", else: pack.status

    changeset(pack, %{
      view_count: pack.view_count + 1,
      status: new_status
    })
  end

  @doc """
  Marks pack as completed.
  """
  def mark_completed(pack) do
    changeset(pack, %{status: "completed"})
  end
end
