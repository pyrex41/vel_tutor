defmodule ViralEngine.PubSub do
  @moduledoc """
  PubSub module for Viral Engine.
  """

  def child_spec do
    {Phoenix.PubSub, name: __MODULE__}
  end
end
