defmodule ViralEngine.Presence.PresenceTracker do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.Accounts.User

  schema "presences" do
    field(:session_id, :string)
    field(:joined_at, :utc_datetime)
    field(:left_at, :utc_datetime)
    belongs_to(:user, User)

    timestamps()
  end

  def changeset(presence, attrs) do
    presence
    |> cast(attrs, [:user_id, :session_id, :joined_at, :left_at])
    |> validate_required([:user_id, :session_id, :joined_at])
    |> unique_constraint([:user_id, :session_id], name: :user_session_unique)
  end

  def track_user(user_id, session_id) do
    attrs = %{
      user_id: user_id,
      session_id: session_id,
      joined_at: DateTime.utc_now()
    }

    case Repo.insert(changeset(%__MODULE__{}, attrs)) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        if changeset.errors[:user_id] || changeset.errors[:session_id] do
          update_existing(user_id, session_id)
        else
          :error
        end
    end
  end

  def untrack_user(user_id, session_id) do
    from(p in __MODULE__,
      where: p.user_id == ^user_id and p.session_id == ^session_id and is_nil(p.left_at)
    )
    |> Repo.update_all(set: [left_at: DateTime.utc_now()])
    |> case do
      {1, _} -> :ok
      _ -> :not_found
    end
  end

  defp update_existing(user_id, session_id) do
    from(p in __MODULE__, where: p.user_id == ^user_id and p.session_id == ^session_id)
    |> Repo.update_all(set: [joined_at: DateTime.utc_now(), left_at: nil])
  end

  def list_active(session_id) do
    from(p in __MODULE__,
      where: p.session_id == ^session_id and is_nil(p.left_at),
      preload: [:user]
    )
    |> Repo.all()
  end
end
