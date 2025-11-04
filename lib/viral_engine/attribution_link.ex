defmodule ViralEngine.AttributionLink do
  @moduledoc """
  Schema for tracking viral attribution links.

  Signed links track referral sources, campaigns, and conversions
  across devices and sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "attribution_links" do
    field(:link_token, :string)
    field(:link_signature, :string)

    field(:referrer_id, :integer)
    field(:campaign, :string)
    field(:source, :string)  # buddy_challenge, results_rally, parent_share, etc.

    field(:target_url, :string)
    field(:metadata, :map, default: %{})

    field(:click_count, :integer, default: 0)
    field(:unique_clicks, :integer, default: 0)
    field(:conversion_count, :integer, default: 0)

    field(:expires_at, :utc_datetime)
    field(:is_active, :boolean, default: true)

    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :link_token,
      :link_signature,
      :referrer_id,
      :campaign,
      :source,
      :target_url,
      :metadata,
      :click_count,
      :unique_clicks,
      :conversion_count,
      :expires_at,
      :is_active
    ])
    |> validate_required([:link_token, :link_signature, :referrer_id, :source])
    |> unique_constraint(:link_token)
  end

  @doc """
  Generates a signed attribution link.
  """
  def generate_signed_link(referrer_id, source, target_url, opts \\ []) do
    campaign = opts[:campaign] || "organic"
    metadata = opts[:metadata] || %{}
    expires_in_days = opts[:expires_in_days] || 30

    link_token = generate_token(referrer_id, source)
    link_signature = sign_token(link_token, referrer_id)

    %{
      link_token: link_token,
      link_signature: link_signature,
      referrer_id: referrer_id,
      campaign: campaign,
      source: source,
      target_url: target_url,
      metadata: metadata,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in_days * 24 * 60 * 60, :second)
    }
  end

  @doc """
  Verifies link signature.
  """
  def verify_signature(link_token, link_signature, referrer_id) do
    expected_signature = sign_token(link_token, referrer_id)
    Plug.Crypto.secure_compare(link_signature, expected_signature)
  end

  @doc """
  Increments click count.
  """
  def increment_clicks(link, is_unique \\ false) do
    attrs = %{click_count: link.click_count + 1}

    attrs = if is_unique do
      Map.put(attrs, :unique_clicks, link.unique_clicks + 1)
    else
      attrs
    end

    changeset(link, attrs)
  end

  @doc """
  Increments conversion count.
  """
  def increment_conversions(link) do
    changeset(link, %{conversion_count: link.conversion_count + 1})
  end

  # Private helpers

  defp generate_token(referrer_id, source) do
    :crypto.hash(:sha256, "#{referrer_id}-#{source}-#{System.system_time(:microsecond)}")
    |> Base.url_encode64()
    |> binary_part(0, 32)
  end

  defp sign_token(token, referrer_id) do
    secret = Application.get_env(:viral_engine, :attribution_secret, "default-secret")

    :crypto.mac(:hmac, :sha256, secret, "#{token}-#{referrer_id}")
    |> Base.url_encode64()
    |> binary_part(0, 32)
  end
end
