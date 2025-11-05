defmodule ViralEngine.ExperimentContext do
  @moduledoc """
  Context for managing A/B testing experiments.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, Experiment, ExperimentAssignment}
  require Logger

  @doc """
  Gets or creates experiment assignment for user.
  """
  def get_or_assign(experiment_key, user_id) do
    experiment = from(e in Experiment,
      where: e.experiment_key == ^experiment_key and e.status == "running"
    )
    |> Repo.one()

    if experiment do
      case get_assignment(experiment.id, user_id) do
        nil ->
          # Assign variant
          variant = Experiment.assign_variant(experiment, user_id)

          assignment_attrs = %{
            experiment_id: experiment.id,
            user_id: user_id,
            variant: variant,
            assigned_at: DateTime.utc_now()
          }

          case Repo.insert(ExperimentAssignment.changeset(%ExperimentAssignment{}, assignment_attrs)) do
            {:ok, _assignment} ->
              Logger.info("User #{user_id} assigned to #{experiment_key}: #{variant}")
              {:ok, variant}

            {:error, _changeset} ->
              {:error, :assignment_failed}
          end

        assignment ->
          {:ok, assignment.variant}
      end
    else
      # No active experiment, return default
      {:default, "control"}
    end
  end

  @doc """
  Records conversion for user's experiment.
  """
  def record_conversion(experiment_key, user_id, value \\ nil) do
    experiment = from(e in Experiment,
      where: e.experiment_key == ^experiment_key
    )
    |> Repo.one()

    if experiment do
      assignment = get_assignment(experiment.id, user_id)

      if assignment && !assignment.converted do
        {:ok, updated} = assignment
          |> ExperimentAssignment.mark_converted(value)
          |> Repo.update()

        Logger.info("Conversion recorded: experiment=#{experiment_key}, user=#{user_id}, variant=#{assignment.variant}")
        {:ok, updated}
      else
        {:error, :already_converted}
      end
    else
      {:error, :experiment_not_found}
    end
  end

  @doc """
  Gets experiment results with statistical significance.
  """
  def get_experiment_results(experiment_id) do
    results = from(a in ExperimentAssignment,
      where: a.experiment_id == ^experiment_id,
      group_by: a.variant,
      select: %{
        variant: a.variant,
        total_users: count(a.id),
        conversions: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", a.converted)),
        total_value: sum(a.conversion_value)
      }
    )
    |> Repo.all()
    |> Enum.map(fn result ->
      conv_rate = if result.total_users > 0 do
        (result.conversions || 0) / result.total_users
      else
        0.0
      end

      result
      |> Map.put(:conversion_rate, Float.round(conv_rate * 100, 2))
      |> Map.put(:conversion_rate_decimal, conv_rate)
    end)

    # Calculate statistical significance if we have control and variant
    with_significance = add_statistical_significance(results)

    with_significance
  end

  @doc """
  Logs exposure event when user sees an experiment variant.
  """
  def log_exposure(experiment_key, user_id, variant) do
    # Record that user was exposed to this variant
    # This is important for accurate conversion rate calculation
    case from(a in ExperimentAssignment,
          join: e in Experiment, on: a.experiment_id == e.id,
          where: e.experiment_key == ^experiment_key and a.user_id == ^user_id,
          select: a
        )
        |> Repo.one() do
      nil ->
        Logger.warning("Exposure logged for unassigned user: #{user_id}, experiment: #{experiment_key}")
        {:error, :not_assigned}

      assignment ->
        # Mark exposure timestamp if not already marked
        if is_nil(assignment.exposed_at) do
          assignment
          |> Ecto.Changeset.change(%{exposed_at: DateTime.utc_now()})
          |> Repo.update()
        else
          {:ok, assignment}
        end
    end
  end

  @doc """
  Starts an experiment (changes status to running).
  """
  def start_experiment(experiment_id) do
    experiment = Repo.get!(Experiment, experiment_id)

    experiment
    |> Experiment.changeset(%{
      status: "running",
      start_date: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Stops an experiment (changes status to completed).
  """
  def stop_experiment(experiment_id) do
    experiment = Repo.get!(Experiment, experiment_id)

    experiment
    |> Experiment.changeset(%{
      status: "completed",
      end_date: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Declares winning variant and stops experiment.
  """
  def declare_winner(experiment_id, winning_variant) do
    experiment = Repo.get!(Experiment, experiment_id)

    metadata = Map.put(experiment.metadata || %{}, "winner", winning_variant)

    experiment
    |> Experiment.changeset(%{
      status: "completed",
      end_date: DateTime.utc_now(),
      metadata: metadata
    })
    |> Repo.update()
  end

  @doc """
  Adds statistical significance calculation to experiment results.
  Uses Z-test for proportions to compare variants against control.
  """
  defp add_statistical_significance(results) do
    # Find control variant
    control = Enum.find(results, fn r -> r.variant == "control" end)

    if control && control.total_users > 0 do
      Enum.map(results, fn result ->
        if result.variant != "control" do
          significance = calculate_z_test(
            control.conversions || 0,
            control.total_users,
            result.conversions || 0,
            result.total_users
          )

          result
          |> Map.put(:p_value, significance.p_value)
          |> Map.put(:is_significant, significance.is_significant)
          |> Map.put(:confidence_interval, significance.confidence_interval)
          |> Map.put(:lift, significance.lift)
        else
          result
          |> Map.put(:p_value, nil)
          |> Map.put(:is_significant, false)
          |> Map.put(:confidence_interval, nil)
          |> Map.put(:lift, 0.0)
        end
      end)
    else
      # No control or insufficient data
      Enum.map(results, fn result ->
        result
        |> Map.put(:p_value, nil)
        |> Map.put(:is_significant, false)
        |> Map.put(:confidence_interval, nil)
        |> Map.put(:lift, 0.0)
      end)
    end
  end

  @doc """
  Calculates Z-test for two proportions.
  Returns p-value and statistical significance at 95% confidence level.
  """
  defp calculate_z_test(control_conversions, control_total, variant_conversions, variant_total) do
    p1 = control_conversions / control_total
    p2 = variant_conversions / variant_total

    # Pooled proportion
    p_pool = (control_conversions + variant_conversions) / (control_total + variant_total)

    # Standard error
    se = :math.sqrt(p_pool * (1 - p_pool) * (1/control_total + 1/variant_total))

    # Z-score
    z_score = if se > 0, do: (p2 - p1) / se, else: 0.0

    # P-value (two-tailed test)
    # Using normal approximation
    p_value = 2 * (1 - normal_cdf(abs(z_score)))

    # 95% confidence interval for difference
    margin = 1.96 * se
    ci_lower = (p2 - p1) - margin
    ci_upper = (p2 - p1) + margin

    # Lift percentage
    lift = if p1 > 0, do: ((p2 - p1) / p1) * 100, else: 0.0

    %{
      p_value: Float.round(p_value, 4),
      is_significant: p_value < 0.05,
      confidence_interval: %{
        lower: Float.round(ci_lower * 100, 2),
        upper: Float.round(ci_upper * 100, 2)
      },
      lift: Float.round(lift, 2),
      z_score: Float.round(z_score, 2)
    }
  end

  @doc """
  Approximates the cumulative distribution function of the standard normal distribution.
  """
  defp normal_cdf(x) do
    # Using erf approximation
    # CDF(x) = 0.5 * (1 + erf(x / sqrt(2)))
    0.5 * (1 + :math.erf(x / :math.sqrt(2)))
  end

  defp get_assignment(experiment_id, user_id) do
    from(a in ExperimentAssignment,
      where: a.experiment_id == ^experiment_id and a.user_id == ^user_id
    )
    |> Repo.one()
  end
end
