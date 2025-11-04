defmodule ViralEngine.ViralPromptLog do
  @moduledoc """
  Schema for tracking viral prompts shown to users.
  Used for throttling, A/B testing analysis, and conversion tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "viral_prompt_logs" do
    field(:user_id, :integer)
    field(:loop_type, :string)  # buddy_challenge, results_rally, etc.
    field(:variant, :string)  # A/B test variant
    field(:prompt_text, :string)
    field(:event_data, :map, default: %{})
    field(:shown_at, :utc_datetime)
    field(:clicked, :boolean, default: false)
    field(:clicked_at, :utc_datetime)
    field(:converted, :boolean, default: false)  # Did user complete the viral action?
    field(:converted_at, :utc_datetime)

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :user_id,
      :loop_type,
      :variant,
      :prompt_text,
      :event_data,
      :shown_at,
      :clicked,
      :clicked_at,
      :converted,
      :converted_at
    ])
    |> validate_required([:user_id, :loop_type, :variant, :prompt_text, :shown_at])
    |> validate_inclusion(:loop_type, [
      "buddy_challenge",
      "results_rally",
      "proud_parent",
      "streak_rescue",
      "flashcard_master"
    ])
  end

  @doc """
  Records a click on a viral prompt.
  """
  def mark_clicked(log_id) do
    from(l in __MODULE__, where: l.id == ^log_id)
    |> ViralEngine.Repo.update_all(set: [clicked: true, clicked_at: DateTime.utc_now()])
  end

  @doc """
  Records a conversion (user completed the viral action).
  """
  def mark_converted(log_id) do
    from(l in __MODULE__, where: l.id == ^log_id)
    |> ViralEngine.Repo.update_all(set: [converted: true, converted_at: DateTime.utc_now()])
  end

  @doc """
  Gets conversion rate for a loop type and variant.
  """
  def get_conversion_rate(loop_type, variant) do
    query = from(l in __MODULE__,
      where: l.loop_type == ^loop_type and l.variant == ^variant,
      select: %{
        total: count(l.id),
        clicks: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.clicked)),
        conversions: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.converted))
      }
    )

    case ViralEngine.Repo.one(query) do
      nil -> %{total: 0, click_rate: 0.0, conversion_rate: 0.0}
      stats ->
        click_rate = if stats.total > 0, do: stats.clicks / stats.total * 100, else: 0.0
        conversion_rate = if stats.total > 0, do: stats.conversions / stats.total * 100, else: 0.0

        %{
          total: stats.total,
          clicks: stats.clicks || 0,
          conversions: stats.conversions || 0,
          click_rate: Float.round(click_rate, 2),
          conversion_rate: Float.round(conversion_rate, 2)
        }
    end
  end
end
