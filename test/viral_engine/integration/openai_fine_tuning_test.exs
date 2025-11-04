defmodule ViralEngine.Integration.OpenAIFineTuningTest do
  use ExUnit.Case, async: true

  import Mox
  alias ViralEngine.Integration.OpenAIFineTuning

  # Setup Mox for HTTP request mocking
  setup :verify_on_exit!

  describe "calculate_cost/2" do
    test "calculates cost for gpt-3.5-turbo" do
      training_tokens = 100_000

      {:ok, cost_info} = OpenAIFineTuning.calculate_cost("gpt-3.5-turbo", training_tokens)

      # 100k tokens / 1k * $0.008 = 0.8
      assert Decimal.equal?(cost_info.training_cost, Decimal.new("0.8"))
      # Only training cost
      assert Decimal.equal?(cost_info.total_cost, Decimal.new("0.8"))
      assert cost_info.currency == "USD"
    end

    test "calculates cost for gpt-4" do
      training_tokens = 50_000

      {:ok, cost_info} = OpenAIFineTuning.calculate_cost("gpt-4", training_tokens)

      # 50k tokens / 1k * $0.03 = 1.5
      assert Decimal.equal?(cost_info.training_cost, Decimal.new("1.5"))
      assert Decimal.equal?(cost_info.total_cost, Decimal.new("1.5"))
    end

    test "calculates cost with usage estimates" do
      training_tokens = 100_000
      opts = [estimated_input_tokens: 10_000, estimated_output_tokens: 5_000]

      {:ok, cost_info} = OpenAIFineTuning.calculate_cost("gpt-3.5-turbo", training_tokens, opts)

      # 10k tokens / 1k * $0.003 = 0.03
      expected_input_cost = Decimal.new("0.03")
      # 5k tokens / 1k * $0.006 = 0.03
      expected_output_cost = Decimal.new("0.03")
      # 100k tokens / 1k * $0.008 = 0.8
      expected_training_cost = Decimal.new("0.8")

      expected_total =
        Decimal.add(
          expected_training_cost,
          Decimal.add(expected_input_cost, expected_output_cost)
        )

      assert Decimal.equal?(cost_info.input_cost, expected_input_cost)
      assert Decimal.equal?(cost_info.output_cost, expected_output_cost)
      assert Decimal.equal?(cost_info.training_cost, expected_training_cost)
      assert Decimal.equal?(cost_info.total_cost, expected_total)
    end

    test "returns error for unsupported model" do
      assert {:error, :unsupported_model} =
               OpenAIFineTuning.calculate_cost("unsupported-model", 1000)
    end
  end

  describe "extract_job_cost_info/1" do
    test "extracts cost info from completed job response" do
      job_response = %{
        "trained_tokens" => 50_000,
        "model" => "gpt-3.5-turbo"
      }

      {:ok, cost_info} = OpenAIFineTuning.extract_job_cost_info(job_response)

      # 50k tokens / 1k * $0.008 = 0.4
      assert Decimal.equal?(cost_info.training_cost, Decimal.new("0.4"))
      assert Decimal.equal?(cost_info.total_cost, Decimal.new("0.4"))
    end

    test "returns error for missing required fields" do
      job_response = %{"status" => "completed"}

      assert {:error, :missing_required_fields} =
               OpenAIFineTuning.extract_job_cost_info(job_response)
    end
  end

  # Note: HTTP request tests would require mocking Finch, which is complex
  # In a real implementation, you would use a library like Bypass or Mox with Finch adapters
  # For now, these functions are tested indirectly through integration tests
end
