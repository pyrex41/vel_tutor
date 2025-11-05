defmodule ViralEngine.ExperimentContextTest do
  use ViralEngine.DataCase
  alias ViralEngine.{ExperimentContext, Experiment, ExperimentAssignment, Repo}

  describe "get_or_assign/2" do
    setup do
      # Create a running experiment
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Test Experiment",
          experiment_key: "test_experiment",
          status: "running",
          variants: %{
            "control" => %{"weight" => 50},
            "variant_a" => %{"weight" => 50}
          }
        })
        |> Repo.insert()

      %{experiment: experiment}
    end

    test "assigns variant to new user", %{experiment: experiment} do
      user_id = 123

      {:ok, variant} = ExperimentContext.get_or_assign(experiment.experiment_key, user_id)

      assert variant in ["control", "variant_a"]

      # Verify assignment was created
      assignment = Repo.get_by(ExperimentAssignment, experiment_id: experiment.id, user_id: user_id)
      assert assignment.variant == variant
    end

    test "returns existing assignment for returning user", %{experiment: experiment} do
      user_id = 124

      {:ok, variant1} = ExperimentContext.get_or_assign(experiment.experiment_key, user_id)
      {:ok, variant2} = ExperimentContext.get_or_assign(experiment.experiment_key, user_id)

      # Should get same variant both times
      assert variant1 == variant2
    end

    test "returns default for non-existent experiment" do
      {:default, "control"} = ExperimentContext.get_or_assign("non_existent", 125)
    end
  end

  describe "record_conversion/3" do
    setup do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Conversion Test",
          experiment_key: "conversion_test",
          status: "running",
          variants: %{"control" => %{"weight" => 100}}
        })
        |> Repo.insert()

      user_id = 200

      {:ok, _assignment} =
        %ExperimentAssignment{}
        |> ExperimentAssignment.changeset(%{
          experiment_id: experiment.id,
          user_id: user_id,
          variant: "control",
          assigned_at: DateTime.utc_now()
        })
        |> Repo.insert()

      %{experiment: experiment, user_id: user_id}
    end

    test "records conversion for user", %{experiment: experiment, user_id: user_id} do
      {:ok, updated} = ExperimentContext.record_conversion(experiment.experiment_key, user_id, Decimal.new("10.50"))

      assert updated.converted == true
      assert updated.conversion_value == Decimal.new("10.50")
      assert updated.conversion_at != nil
    end

    test "prevents duplicate conversion", %{experiment: experiment, user_id: user_id} do
      {:ok, _} = ExperimentContext.record_conversion(experiment.experiment_key, user_id)
      {:error, :already_converted} = ExperimentContext.record_conversion(experiment.experiment_key, user_id)
    end
  end

  describe "get_experiment_results/1 with statistical significance" do
    setup do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Stats Test",
          experiment_key: "stats_test",
          status: "running",
          variants: %{
            "control" => %{"weight" => 50},
            "variant_a" => %{"weight" => 50}
          }
        })
        |> Repo.insert()

      # Create control assignments (10 users, 2 conversions = 20% CR)
      for i <- 1..10 do
        {:ok, assignment} =
          %ExperimentAssignment{}
          |> ExperimentAssignment.changeset(%{
            experiment_id: experiment.id,
            user_id: i,
            variant: "control",
            assigned_at: DateTime.utc_now(),
            converted: i <= 2
          })
          |> Repo.insert()

        if i <= 2 do
          assignment
          |> ExperimentAssignment.mark_converted(Decimal.new("5.00"))
          |> Repo.update()
        end
      end

      # Create variant_a assignments (10 users, 5 conversions = 50% CR)
      for i <- 11..20 do
        {:ok, assignment} =
          %ExperimentAssignment{}
          |> ExperimentAssignment.changeset(%{
            experiment_id: experiment.id,
            user_id: i,
            variant: "variant_a",
            assigned_at: DateTime.utc_now(),
            converted: i <= 15
          })
          |> Repo.insert()

        if i <= 15 do
          assignment
          |> ExperimentAssignment.mark_converted(Decimal.new("5.00"))
          |> Repo.update()
        end
      end

      %{experiment: experiment}
    end

    test "calculates conversion rates correctly", %{experiment: experiment} do
      results = ExperimentContext.get_experiment_results(experiment.id)

      control = Enum.find(results, &(&1.variant == "control"))
      variant_a = Enum.find(results, &(&1.variant == "variant_a"))

      assert control.conversion_rate == 20.0
      assert variant_a.conversion_rate == 50.0
    end

    test "calculates statistical significance", %{experiment: experiment} do
      results = ExperimentContext.get_experiment_results(experiment.id)

      variant_a = Enum.find(results, &(&1.variant == "variant_a"))

      # With 20% vs 50% conversion rate and 10 users each,
      # this should show some significance
      assert is_float(variant_a.p_value)
      assert is_boolean(variant_a.is_significant)
      assert is_map(variant_a.confidence_interval)
      assert is_float(variant_a.lift)
    end

    test "calculates lift percentage", %{experiment: experiment} do
      results = ExperimentContext.get_experiment_results(experiment.id)

      variant_a = Enum.find(results, &(&1.variant == "variant_a"))

      # 50% vs 20% = 150% lift
      assert variant_a.lift == 150.0
    end
  end

  describe "log_exposure/3" do
    setup do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Exposure Test",
          experiment_key: "exposure_test",
          status: "running",
          variants: %{"control" => %{"weight" => 100}}
        })
        |> Repo.insert()

      user_id = 300

      {:ok, assignment} =
        %ExperimentAssignment{}
        |> ExperimentAssignment.changeset(%{
          experiment_id: experiment.id,
          user_id: user_id,
          variant: "control",
          assigned_at: DateTime.utc_now()
        })
        |> Repo.insert()

      %{experiment: experiment, user_id: user_id, assignment: assignment}
    end

    test "logs exposure timestamp", %{experiment: experiment, user_id: user_id, assignment: assignment} do
      assert assignment.exposed_at == nil

      {:ok, updated} = ExperimentContext.log_exposure(experiment.experiment_key, user_id, "control")

      assert updated.exposed_at != nil
    end

    test "does not update exposure if already logged", %{experiment: experiment, user_id: user_id} do
      {:ok, first} = ExperimentContext.log_exposure(experiment.experiment_key, user_id, "control")
      {:ok, second} = ExperimentContext.log_exposure(experiment.experiment_key, user_id, "control")

      assert first.exposed_at == second.exposed_at
    end

    test "returns error for unassigned user" do
      {:error, :not_assigned} = ExperimentContext.log_exposure("exposure_test", 999, "control")
    end
  end

  describe "experiment lifecycle management" do
    test "start_experiment/1 changes status to running" do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Lifecycle Test",
          experiment_key: "lifecycle_test",
          status: "draft",
          variants: %{"control" => %{"weight" => 100}}
        })
        |> Repo.insert()

      assert experiment.status == "draft"
      assert experiment.start_date == nil

      {:ok, updated} = ExperimentContext.start_experiment(experiment.id)

      assert updated.status == "running"
      assert updated.start_date != nil
    end

    test "stop_experiment/1 changes status to completed" do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Stop Test",
          experiment_key: "stop_test",
          status: "running",
          start_date: DateTime.utc_now(),
          variants: %{"control" => %{"weight" => 100}}
        })
        |> Repo.insert()

      {:ok, updated} = ExperimentContext.stop_experiment(experiment.id)

      assert updated.status == "completed"
      assert updated.end_date != nil
    end

    test "declare_winner/2 marks winner in metadata" do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Winner Test",
          experiment_key: "winner_test",
          status: "running",
          variants: %{
            "control" => %{"weight" => 50},
            "variant_a" => %{"weight" => 50}
          }
        })
        |> Repo.insert()

      {:ok, updated} = ExperimentContext.declare_winner(experiment.id, "variant_a")

      assert updated.status == "completed"
      assert updated.metadata["winner"] == "variant_a"
      assert updated.end_date != nil
    end
  end

  describe "deterministic variant assignment" do
    test "same user_id always gets same variant" do
      {:ok, experiment} =
        %Experiment{}
        |> Experiment.changeset(%{
          name: "Deterministic Test",
          experiment_key: "deterministic_test",
          status: "running",
          variants: %{
            "control" => %{"weight" => 50},
            "variant_a" => %{"weight" => 50}
          }
        })
        |> Repo.insert()

      user_id = 500

      # Call multiple times
      {:ok, variant1} = ExperimentContext.get_or_assign("deterministic_test", user_id)

      # Delete assignment to test deterministic assignment algorithm
      Repo.get_by(ExperimentAssignment, experiment_id: experiment.id, user_id: user_id)
      |> Repo.delete()

      {:ok, variant2} = ExperimentContext.get_or_assign("deterministic_test", user_id)

      # Should get same variant due to deterministic hash
      assert variant1 == variant2
    end
  end
end
