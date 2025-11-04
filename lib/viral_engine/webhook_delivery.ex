defmodule ViralEngine.WebhookDelivery do
  @moduledoc """
  Schema for tracking webhook delivery attempts and status.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "webhook_deliveries" do
    field(:webhook_id, :integer)
    field(:event_type, :string)
    field(:payload, :map)
    field(:status, :string, default: "pending")
    field(:attempt_count, :integer, default: 0)
    field(:last_attempt_at, :utc_datetime)
    field(:error_message, :string)
    field(:signature, :string)
    field(:response_code, :integer)
    field(:response_body, :string)

    timestamps()
  end

  @required_fields [:webhook_id, :event_type, :payload]
  @optional_fields [
    :status,
    :attempt_count,
    :last_attempt_at,
    :error_message,
    :signature,
    :response_code,
    :response_body
  ]

  @valid_statuses ~w(pending success failed)

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:attempt_count, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
  end
end
