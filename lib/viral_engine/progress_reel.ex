defmodule ViralEngine.ProgressReel do
  @moduledoc """
  Schema for parent progress reels.

  Reels are short, shareable visual summaries of student achievements
  triggered by high ratings or milestones.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "progress_reels" do
    field(:student_id, :integer)
    field(:reel_type, :string)  # high_score, milestone, streak, level_up
    field(:reel_token, :string)

    field(:title, :string)
    field(:subtitle, :string)

    field(:trigger_event, :map, default: %{})
    # Event that triggered reel: assessment_id, score, subject, etc.

    field(:reel_data, :map, default: %{})
    # Stats and achievements for the reel (COPPA-compliant)

    field(:media_url, :string)  # Generated video/image URL
    field(:media_type, :string, default: "image")  # image, video, animation

    field(:generation_status, :string, default: "pending")
    # pending, generating, completed, failed

    field(:view_count, :integer, default: 0)
    field(:share_count, :integer, default: 0)

    field(:is_shared_with_parent, :boolean, default: false)
    field(:parent_shared_at, :utc_datetime)

    field(:expires_at, :utc_datetime)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(progress_reel, attrs) do
    progress_reel
    |> cast(attrs, [
      :student_id,
      :reel_type,
      :reel_token,
      :title,
      :subtitle,
      :trigger_event,
      :reel_data,
      :media_url,
      :media_type,
      :generation_status,
      :view_count,
      :share_count,
      :is_shared_with_parent,
      :parent_shared_at,
      :expires_at,
      :metadata
    ])
    |> validate_required([:student_id, :reel_type, :reel_token, :title])
    |> validate_inclusion(:reel_type, ["high_score", "milestone", "streak", "level_up"])
    |> validate_inclusion(:generation_status, ["pending", "generating", "completed", "failed"])
    |> unique_constraint(:reel_token)
  end

  @doc """
  Generates a unique reel token.
  """
  def generate_token(student_id, reel_type) do
    :crypto.hash(:sha256, "#{student_id}-#{reel_type}-#{System.system_time(:microsecond)}")
    |> Base.url_encode64()
    |> binary_part(0, 32)
  end

  @doc """
  Increments view count.
  """
  def increment_views(reel) do
    changeset(reel, %{view_count: reel.view_count + 1})
  end

  @doc """
  Increments share count.
  """
  def increment_shares(reel) do
    changeset(reel, %{
      share_count: reel.share_count + 1,
      is_shared_with_parent: true,
      parent_shared_at: reel.parent_shared_at || DateTime.utc_now()
    })
  end

  @doc """
  Marks reel as completed.
  """
  def mark_completed(reel, media_url) do
    changeset(reel, %{
      generation_status: "completed",
      media_url: media_url
    })
  end

  @doc """
  Marks reel as failed.
  """
  def mark_failed(reel) do
    changeset(reel, %{generation_status: "failed"})
  end
end
