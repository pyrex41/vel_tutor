defmodule ViralEngine.Integration.GroqAdapterTest do
  use ExUnit.Case, async: true

  alias ViralEngine.Integration.GroqAdapter

  describe "init/1" do
    test "initializes with Groq settings" do
      adapter = GroqAdapter.init(api_key: "test_key")
      assert adapter.api_key == "test_key"
      assert adapter.base_url == "https://api.groq.com/openai/v1"
      assert adapter.max_tokens == 8192
    end
  end
end
