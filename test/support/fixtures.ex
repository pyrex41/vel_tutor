defmodule ViralEngine.Fixtures do
  @moduledoc """
  Test data factories for integration testing.
  """

  alias ViralEngine.{Repo, Accounts.User, Cohort}
  alias ViralEngine.Support.DateTimeHelpers

  def user_attrs(attrs \\ %{}) do
    %{
      email: "user#{:rand.uniform(10000)}@test.com",
      name: "Test User",
      password: "password123",
      persona: "student",
      role: "student"
    }
    |> Map.merge(attrs)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(user_attrs(attrs))
    |> User.registration_changeset(user_attrs(attrs))
    |> Repo.insert!()
  end

  def cohort_attrs(attrs \\ %{}) do
    %{
      name: "Test Cohort #{:rand.uniform(1000)}",
      start_date: DateTimeHelpers.now_for_ecto(),
      end_date: DateTimeHelpers.now_for_ecto() |> DateTime.add(30, :day),
      grade_level: 9,
      subject: "Math"
    }
    |> Map.merge(attrs)
  end

  def create_cohort(attrs \\ %{}) do
    %Cohort{}
    |> Cohort.changeset(cohort_attrs(attrs))
    |> Repo.insert!()
  end

  def valid_event(user_id, type, context \\ %{}) do
    %{
      type: type,
      user_id: user_id,
      context: context,
      timestamp: DateTimeHelpers.now_for_ecto()
    }
  end
end