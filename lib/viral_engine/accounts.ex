defmodule ViralEngine.Accounts do
  alias ViralEngine.Repo
  alias ViralEngine.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_session_token(token) do
    Repo.get_by(User, session_token: token)
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
