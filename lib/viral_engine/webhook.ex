defmodule ViralEngine.Webhook do
  @moduledoc """
  Schema for webhook configurations allowing users to receive event notifications.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "webhooks" do
    field(:user_id, :integer)
    field(:organization_id, :integer)
    field(:url, :string)
    field(:secret, :string)
    field(:event_types, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)
    field(:description, :string)

    timestamps()
  end

  @valid_event_types ~w(
    task.completed
    task.failed
    task.cancelled
    batch.completed
    batch.failed
    batch.cancelled
    workflow.paused
    workflow.completed
    workflow.failed
  )

  @required_fields [:user_id, :url, :event_types]
  @optional_fields [:organization_id, :secret, :is_active, :description]

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_url()
    |> validate_event_types()
    |> generate_secret_if_nil()
  end

  defp validate_url(changeset) do
    case get_change(changeset, :url) do
      nil ->
        changeset

      url ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
            # Prevent SSRF attacks
            if is_safe_url?(host) do
              changeset
            else
              add_error(changeset, :url, "URL points to internal/private network")
            end

          _ ->
            add_error(changeset, :url, "must be a valid HTTP/HTTPS URL")
        end
    end
  end

  defp validate_event_types(changeset) do
    case get_change(changeset, :event_types) do
      nil ->
        changeset

      types when is_list(types) ->
        invalid_types = Enum.filter(types, fn type -> type not in @valid_event_types end)

        if Enum.empty?(invalid_types) do
          changeset
        else
          add_error(changeset, :event_types, "contains invalid event types: #{inspect(invalid_types)}")
        end

      _ ->
        add_error(changeset, :event_types, "must be a list of event type strings")
    end
  end

  defp generate_secret_if_nil(changeset) do
    case get_field(changeset, :secret) do
      nil ->
        # Generate a secure random secret for HMAC
        secret = Base.encode64(:crypto.strong_rand_bytes(32))
        put_change(changeset, :secret, secret)

      _ ->
        changeset
    end
  end

  defp is_safe_url?(host) do
    # Block common internal/private IP ranges and localhost
    blocked_patterns = ~r/(localhost|127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.)/

    not String.match?(host, blocked_patterns)
  end
end
