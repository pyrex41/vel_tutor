defmodule ViralEngine.AnalyticsEvent do
  @moduledoc """
  Schema for tracking analytics events in viral loops.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "analytics_events" do
    field(:event_type, :string)
    field(:user_id, :integer)
    field(:loop_type, :string)
    field(:action, :string)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :user_id, :loop_type, :action, :metadata])
    |> validate_required([:event_type])
  end
end