defmodule ViralEngine.AuditLog do
  @moduledoc """
  Schema for audit logs tracking user actions, AI calls, and system events.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field(:user_id, :integer)
    field(:action, :string)
    field(:payload, :map)
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:task_id, :integer)
    field(:provider, :string)
    field(:model, :string)
    field(:tokens_used, :integer)
    field(:cost, :decimal)
    field(:latency_ms, :integer)
    field(:event_type, :string)
    field(:consent_flag, :boolean, default: false)
    field(:timestamp, :utc_datetime)

    timestamps()
  end

  @required_fields [:action, :event_type, :timestamp]
  @optional_fields [
    :user_id,
    :payload,
    :ip_address,
    :user_agent,
    :task_id,
    :provider,
    :model,
    :tokens_used,
    :cost,
    :latency_ms,
    :consent_flag
  ]

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:event_type, ["user_action", "ai_interaction", "system_event"])
    |> validate_pii()
  end

  defp validate_pii(changeset) do
    payload = get_change(changeset, :payload)
    consent = get_change(changeset, :consent_flag) || false

    if payload && contains_pii?(payload) && !consent do
      add_error(changeset, :consent_flag, "PII detected but consent_flag not set")
    else
      changeset
    end
  end

  defp contains_pii?(payload) when is_map(payload) do
    pii_keywords = ["email", "ssn", "phone", "address", "credit_card"]

    Enum.any?(Map.keys(payload), fn key ->
      key_str = to_string(key) |> String.downcase()
      Enum.any?(pii_keywords, &String.contains?(key_str, &1))
    end)
  end

  defp contains_pii?(_), do: false
end
