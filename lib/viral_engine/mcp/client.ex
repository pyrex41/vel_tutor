defmodule ViralEngine.MCP.Client do
  @moduledoc """
  MCP Client for inter-agent communication.

  Provides a simple interface for agents to call each other via the MCP protocol.
  Handles routing to the appropriate agent endpoints.
  """

  require Logger

  @doc """
  Calls an MCP agent with the specified method and parameters.

  ## Parameters
  - agent: Agent name (e.g., "personalization-agent", "incentives-agent")
  - method: Method to call on the agent
  - params: Parameters to pass to the method

  ## Returns
  - {:ok, result} - Successful call
  - {:error, reason} - Call failed
  """
  def call_agent(agent, method, params) do
    case agent do
      "personalization-agent" ->
        call_personalization_agent(method, params)

      "incentives-agent" ->
        call_incentives_agent(method, params)

      _ ->
        {:error, :unknown_agent}
    end
  end

  # Private functions for each agent

  defp call_personalization_agent("personalize", params) do
    # Call the Personalization Agent GenServer
    case ViralEngine.Agents.Personalization.personalize(params) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_personalization_agent(_method, _params) do
    {:error, :method_not_found}
  end

  defp call_incentives_agent("grant_reward", params) do
    # Call the Incentives Agent GenServer
    case ViralEngine.Agents.IncentivesEconomy.grant_reward(
           params["user_id"],
           params["reward_type"],
           params["amount"],
           params["context"] || %{}
         ) do
      {:ok, reward} -> {:ok, reward}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_incentives_agent("check_balance", params) do
    # Call the Incentives Agent GenServer
    case ViralEngine.Agents.IncentivesEconomy.check_balance(
           params["user_id"],
           params["reward_type"]
         ) do
      {:ok, balance} -> {:ok, balance}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_incentives_agent("redeem_reward", params) do
    # Call the Incentives Agent GenServer
    case ViralEngine.Agents.IncentivesEconomy.redeem_reward(
           params["user_id"],
           params["reward_type"],
           params["amount"]
         ) do
      {:ok, redemption} -> {:ok, redemption}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_incentives_agent(_method, _params) do
    {:error, :method_not_found}
  end
end
