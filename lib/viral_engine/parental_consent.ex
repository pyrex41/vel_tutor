defmodule ViralEngine.ParentalConsent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parental_consents" do
    field :user_id, :integer
    field :parent_email, :string
    field :consent_given, :boolean, default: false
    field :consent_date, :utc_datetime
    field :ip_address, :string
    field :consent_text, :string
    field :withdrawn_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(parental_consent, attrs) do
    parental_consent
    |> cast(attrs, [
      :user_id,
      :parent_email,
      :consent_given,
      :consent_date,
      :ip_address,
      :consent_text,
      :withdrawn_at
    ])
    |> validate_required([:user_id, :parent_email])
    |> validate_format(:parent_email, ~r/^[^\s]+@[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> foreign_key_constraint(:user_id)
  end
end
