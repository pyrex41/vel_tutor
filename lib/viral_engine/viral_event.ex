defmodule ViralEngine.ViralEvent do
  @moduledoc """
  Schema for viral_events table.

  Stores viral growth events triggered by user actions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "viral_events" do
    field(:event_type, :string)
    field(:event_data, :map, default: %{})
    field(:user_id, :integer)
    field(:timestamp, :utc_datetime)
    field(:k_factor_impact, :float, default: 0.0)
    field(:processed, :boolean, default: false)

    timestamps()
  end

  @doc false
  def changeset(viral_event, attrs) do
    viral_event
    |> cast(attrs, [:event_type, :event_data, :user_id, :timestamp, :k_factor_impact, :processed])
    |> validate_required([:event_type, :user_id, :timestamp])
  end
end
