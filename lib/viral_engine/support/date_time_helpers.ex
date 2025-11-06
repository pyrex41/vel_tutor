defmodule ViralEngine.Support.DateTimeHelpers do
  @moduledoc """
  Helper functions for DateTime handling with Ecto compatibility.
  """

  @doc """
  Truncate DateTime to seconds for Ecto :utc_datetime compatibility.
  """
  @spec truncate_for_ecto(DateTime.t()) :: DateTime.t()
  def truncate_for_ecto(%DateTime{} = dt) do
    DateTime.truncate(dt, :second)
  end

  @doc """
  Create Ecto-compatible timestamp for now.
  """
  @spec now_for_ecto() :: DateTime.t()
  def now_for_ecto do
    DateTime.utc_now() |> truncate_for_ecto()
  end
end