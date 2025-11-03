defmodule ViralEngine.AgentDecision do
  @moduledoc """
  Schema for agent_decisions table.

  Stores decisions made by MCP agents for auditing and analytics.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "agent_decisions" do
    field(:agent_id, :string)
    field(:decision_type, :string)
    field(:decision_data, :map, default: %{})
    field(:timestamp, :utc_datetime)
    field(:viral_loop_id, :string)
    field(:latency_ms, :integer)
    field(:success, :boolean, default: true)

    timestamps()
  end

  @doc false
  def changeset(agent_decision, attrs) do
    agent_decision
    |> cast(attrs, [
      :agent_id,
      :decision_type,
      :decision_data,
      :timestamp,
      :viral_loop_id,
      :latency_ms,
      :success
    ])
    |> validate_required([:agent_id, :decision_type, :timestamp])
  end
end
