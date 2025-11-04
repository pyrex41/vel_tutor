defmodule ViralEngine.AttributionEvent do
  @moduledoc """
  Schema for tracking attribution events (clicks, visits, conversions).

  Enables cross-device attribution and conversion funnel analysis.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "attribution_events" do
    field(:link_id, :integer)
    field(:event_type, :string)  # click, visit, signup, conversion
    field(:user_id, :integer)
    field(:session_id, :string)

    field(:device_fingerprint, :string)
    field(:ip_address, :string)
    field(:user_agent, :string)

    field(:referrer_url, :string)
    field(:landing_page, :string)

    field(:metadata, :map, default: %{})
    field(:converted, :boolean, default: false)
    field(:conversion_value, :decimal)

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :link_id,
      :event_type,
      :user_id,
      :session_id,
      :device_fingerprint,
      :ip_address,
      :user_agent,
      :referrer_url,
      :landing_page,
      :metadata,
      :converted,
      :conversion_value
    ])
    |> validate_required([:link_id, :event_type])
    |> validate_inclusion(:event_type, ["click", "visit", "signup", "conversion"])
  end

  @doc """
  Generates device fingerprint for cross-device tracking.
  """
  def generate_device_fingerprint(user_agent, ip_address) do
    :crypto.hash(:sha256, "#{user_agent}-#{ip_address}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end
end
