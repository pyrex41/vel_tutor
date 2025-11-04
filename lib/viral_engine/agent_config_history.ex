defmodule ViralEngine.AgentConfigHistory do
  use Ecto.Schema

  schema "agent_config_histories" do
    field(:agent_id, :integer)
    field(:config, :map)
    field(:changed_at, :naive_datetime)

    timestamps()
  end
end
