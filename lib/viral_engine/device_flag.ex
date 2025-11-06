defmodule ViralEngine.DeviceFlag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_flags" do
    field :device_id, :string
    field :ip_address, :string
    field :user_agent, :string
    field :fingerprint, :string
    field :flag_type, :string
    field :flag_reason, :string
    field :risk_score, :float, default: 0.0
    field :blocked, :boolean, default: false
    field :blocked_at, :utc_datetime
    field :cleared_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(device_flag, attrs) do
    device_flag
    |> cast(attrs, [
      :device_id,
      :ip_address,
      :user_agent,
      :fingerprint,
      :flag_type,
      :flag_reason,
      :risk_score,
      :blocked,
      :blocked_at,
      :cleared_at
    ])
    |> validate_required([:device_id, :ip_address, :flag_type])
    |> validate_number(:risk_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 10.0)
    |> validate_inclusion(:flag_type, [
      "bot",
      "fraud",
      "abuse",
      "spam",
      "duplicate",
      "suspicious"
    ])
  end
end
