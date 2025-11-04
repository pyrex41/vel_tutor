defmodule ViralEngine.ViralMetricsContext do
  @moduledoc """
  Context for computing viral metrics including K-factor.

  K-factor = (invites sent / user) * (conversion rate)
  """

  import Ecto.Query
  alias ViralEngine.{Repo, AttributionLink, AttributionEvent}
  require Logger

  @doc """
  Computes K-factor for a time period.

  K-factor = Average invites per user * Conversion rate
  """
  def compute_k_factor(opts \\ []) do
    days = opts[:days] || 7
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Get total users who sent invites
    active_users = from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      select: count(l.referrer_id, :distinct)
    )
    |> Repo.one() || 0

    # Get total invites sent
    total_invites = from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      select: sum(l.click_count)
    )
    |> Repo.one() || 0

    # Get total conversions
    total_conversions = from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      select: sum(l.conversion_count)
    )
    |> Repo.one() || 0

    # Calculate metrics
    avg_invites_per_user = if active_users > 0, do: total_invites / active_users, else: 0.0
    conversion_rate = if total_invites > 0, do: total_conversions / total_invites, else: 0.0
    k_factor = avg_invites_per_user * conversion_rate

    %{
      k_factor: Float.round(k_factor, 3),
      active_users: active_users,
      total_invites: total_invites,
      total_conversions: total_conversions,
      avg_invites_per_user: Float.round(avg_invites_per_user, 2),
      conversion_rate: Float.round(conversion_rate * 100, 2),  # As percentage
      period_days: days,
      computed_at: DateTime.utc_now()
    }
  end

  @doc """
  Computes K-factor by viral loop type.
  """
  def compute_k_factor_by_source(days \\ 7) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      group_by: l.source,
      select: %{
        source: l.source,
        active_users: count(l.referrer_id, :distinct),
        total_invites: sum(l.click_count),
        total_conversions: sum(l.conversion_count)
      }
    )
    |> Repo.all()
    |> Enum.map(fn source_data ->
      avg_invites = if source_data.active_users > 0 do
        source_data.total_invites / source_data.active_users
      else
        0.0
      end

      conv_rate = if source_data.total_invites > 0 do
        source_data.total_conversions / source_data.total_invites
      else
        0.0
      end

      k_factor = avg_invites * conv_rate

      Map.merge(source_data, %{
        avg_invites_per_user: Float.round(avg_invites, 2),
        conversion_rate: Float.round(conv_rate * 100, 2),
        k_factor: Float.round(k_factor, 3)
      })
    end)
    |> Enum.sort_by(& &1.k_factor, :desc)
  end

  @doc """
  Gets viral growth metrics over time (daily).
  """
  def get_growth_timeline(days \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Group by date
    from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      group_by: fragment("date(?)", l.inserted_at),
      order_by: [asc: fragment("date(?)", l.inserted_at)],
      select: %{
        date: fragment("date(?)", l.inserted_at),
        links_created: count(l.id),
        clicks: sum(l.click_count),
        conversions: sum(l.conversion_count)
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets top referrers (most viral users).
  """
  def get_top_referrers(opts \\ []) do
    days = opts[:days] || 30
    limit = opts[:limit] || 10

    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      group_by: l.referrer_id,
      order_by: [desc: sum(l.conversion_count), desc: sum(l.click_count)],
      limit: ^limit,
      select: %{
        referrer_id: l.referrer_id,
        links_created: count(l.id),
        total_clicks: sum(l.click_count),
        total_conversions: sum(l.conversion_count)
      }
    )
    |> Repo.all()
    |> Enum.map(fn referrer ->
      conv_rate = if referrer.total_clicks > 0 do
        referrer.total_conversions / referrer.total_clicks * 100
      else
        0.0
      end

      Map.put(referrer, :conversion_rate, Float.round(conv_rate, 2))
    end)
  end

  @doc """
  Computes cycle time (time from invite to conversion).
  """
  def compute_cycle_time(days \\ 7) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Get conversions with timestamps
    from(e in AttributionEvent,
      join: l in AttributionLink, on: e.link_id == l.id,
      where: e.event_type == "conversion" and e.inserted_at > ^cutoff,
      select: %{
        link_created: l.inserted_at,
        conversion_at: e.inserted_at
      }
    )
    |> Repo.all()
    |> Enum.map(fn event ->
      DateTime.diff(event.conversion_at, event.link_created, :second)
    end)
    |> case do
      [] ->
        %{avg_cycle_time_hours: 0.0, median_cycle_time_hours: 0.0}

      times ->
        avg = Enum.sum(times) / length(times) / 3600  # Convert to hours
        median = Enum.at(Enum.sort(times), div(length(times), 2)) / 3600

        %{
          avg_cycle_time_hours: Float.round(avg, 2),
          median_cycle_time_hours: Float.round(median, 2),
          sample_size: length(times)
        }
    end
  end

  @doc """
  Computes viral coefficient (users referred per existing user).
  """
  def compute_viral_coefficient(days \\ 7) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    total_users = from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      select: count(l.referrer_id, :distinct)
    )
    |> Repo.one() || 0

    new_users = from(l in AttributionLink,
      where: l.inserted_at > ^cutoff,
      select: sum(l.conversion_count)
    )
    |> Repo.one() || 0

    coefficient = if total_users > 0, do: new_users / total_users, else: 0.0

    %{
      viral_coefficient: Float.round(coefficient, 3),
      existing_users: total_users,
      new_users_referred: new_users,
      period_days: days
    }
  end
end
