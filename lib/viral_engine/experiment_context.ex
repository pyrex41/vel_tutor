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
            {:ok, assignment} ->
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
  Gets experiment results.
  """
  def get_experiment_results(experiment_id) do
    from(a in ExperimentAssignment,
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
        (result.conversions || 0) / result.total_users * 100
      else
        0.0
      end

      Map.put(result, :conversion_rate, Float.round(conv_rate, 2))
    end)
  end

  defp get_assignment(experiment_id, user_id) do
    from(a in ExperimentAssignment,
      where: a.experiment_id == ^experiment_id and a.user_id == ^user_id
    )
    |> Repo.one()
  end
end
