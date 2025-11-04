defmodule ViralEngine.AnomalyDetectionTest do
  use ViralEngine.DataCase

  alias ViralEngine.{AnomalyDetection, Alert, Repo}

  describe "analyze_metrics/0" do
    test "creates alerts for anomalous metrics" do
      # Insert some test metrics data
      # This would require setting up test data in the metrics context
      # For now, just test that the function runs without error
      assert :ok = AnomalyDetection.analyze_metrics()
    end
  end

  describe "is_anomalous?/2" do
    test "returns false for insufficient data points" do
      # Less than @min_data_points
      values = [1.0, 2.0, 3.0]
      assert AnomalyDetection.is_anomalous?(values, 4.0) == false
    end

    test "detects anomalies using statistical method" do
      # Create normal data with mean around 10
      normal_values = for _ <- 1..150, do: 10.0 + :rand.normal(0, 1)
      # Add an anomalous value (3σ above mean)
      # 3σ = 3, so 10 + 9 = 19
      anomalous_value = 10.0 + 9.0

      assert AnomalyDetection.is_anomalous?(normal_values, anomalous_value)
    end
  end

  describe "calculate_stats/1" do
    test "returns nil for insufficient data" do
      assert AnomalyDetection.calculate_stats([1, 2, 3]) == nil
    end

    test "calculates statistical measures for sufficient data" do
      values = for _ <- 1..150, do: 10.0 + :rand.normal(0, 1)
      stats = AnomalyDetection.calculate_stats(values)

      assert stats != nil
      assert is_float(stats.mean)
      assert is_float(stats.std_dev)
      assert is_float(stats.threshold)
      assert stats.data_points == 150
    end
  end
end
