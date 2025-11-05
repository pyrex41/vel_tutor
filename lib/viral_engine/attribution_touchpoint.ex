defmodule ViralEngine.AttributionTouchpoint do
  @moduledoc """
  Tracks all attribution touchpoints for multi-touch attribution analysis.

  While last-touch attribution is used for conversion credit, we store all
  touchpoints to enable future multi-touch attribution models and journey analysis.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "attribution_touchpoints" do
    field :user_id, :integer
    field :link_id, :integer
    field :source, :string
    field :touched_at, :utc_datetime
    field :attribution_weight, :float, default: 1.0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc """
  Creates a changeset for an attribution touchpoint.

  ## Required fields
  - user_id: User who clicked/interacted
  - link_id: Attribution link ID (foreign key to attribution_links)
  - source: Source of the touchpoint (e.g., "progress_reel", "challenge", "rally")
  - touched_at: Timestamp of interaction

  ## Optional fields
  - attribution_weight: Weight for multi-touch models (default 1.0)
  - metadata: Additional context (utm params, device info, etc.)
  """
  def changeset(touchpoint, attrs) do
    touchpoint
    |> cast(attrs, [:user_id, :link_id, :source, :touched_at, :attribution_weight, :metadata])
    |> validate_required([:user_id, :link_id, :source, :touched_at])
    |> validate_number(:attribution_weight, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end
