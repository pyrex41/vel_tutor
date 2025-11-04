defmodule ViralEngine.Integration.AdapterBehaviour do
  @moduledoc """
  Behaviour for AI provider adapters.
  """

  @callback init(opts :: keyword()) :: struct()
  @callback chat_completion(prompt :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
