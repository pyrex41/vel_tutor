defmodule ViralEngine.AttributionContext do
  @moduledoc """
  Context for managing attribution links and tracking events.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, AttributionLink, AttributionEvent}
  require Logger

  @doc """
  Creates a signed attribution link.
  """
  def create_attribution_link(referrer_id, source, target_url, opts \\ []) do
    link_attrs = AttributionLink.generate_signed_link(referrer_id, source, target_url, opts)

    %AttributionLink{}
    |> AttributionLink.changeset(link_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets attribution link by token.
  """
  def get_link_by_token(link_token) do
    from(l in AttributionLink,
      where: l.link_token == ^link_token and l.is_active == true
    )
    |> Repo.one()
  end

  @doc """
  Tracks a click event.
  """
  def track_click(link_token, conn_params) do
    with link when not is_nil(link) <- get_link_by_token(link_token),
         true <- AttributionLink.verify_signature(link.link_token, link.link_signature, link.referrer_id) do

      # Check if unique click (by device fingerprint or session)
      device_fingerprint = AttributionEvent.generate_device_fingerprint(
        conn_params[:user_agent] || "",
        conn_params[:ip_address] || ""
      )

      is_unique = !has_recent_click?(link.id, device_fingerprint)

      # Update link click count
      {:ok, updated_link} = link
        |> AttributionLink.increment_clicks(is_unique)
        |> Repo.update()

      # Record event
      event_attrs = %{
        link_id: link.id,
        event_type: "click",
        session_id: conn_params[:session_id],
        device_fingerprint: device_fingerprint,
        ip_address: conn_params[:ip_address],
        user_agent: conn_params[:user_agent],
        referrer_url: conn_params[:referrer],
        landing_page: conn_params[:landing_page]
      }

      {:ok, event} = %AttributionEvent{}
        |> AttributionEvent.changeset(event_attrs)
        |> Repo.insert()

      Logger.info("Attribution click tracked: link=#{link.id}, unique=#{is_unique}")

      {:ok, updated_link, event}
    else
      nil ->
        {:error, :link_not_found}

      false ->
        {:error, :invalid_signature}
    end
  end

  @doc """
  Tracks a conversion event.
  """
  def track_conversion(link_token, user_id, conversion_value \\ nil) do
    link = get_link_by_token(link_token)

    if link do
      # Update link conversion count
      {:ok, updated_link} = link
        |> AttributionLink.increment_conversions()
        |> Repo.update()

      # Record conversion event
      event_attrs = %{
        link_id: link.id,
        event_type: "conversion",
        user_id: user_id,
        converted: true,
        conversion_value: conversion_value,
        metadata: %{referrer_id: link.referrer_id, source: link.source}
      }

      {:ok, event} = %AttributionEvent{}
        |> AttributionEvent.changeset(event_attrs)
        |> Repo.insert()

      Logger.info("Conversion tracked: link=#{link.id}, user=#{user_id}, referrer=#{link.referrer_id}")

      # Reward referrer (integrate with XP/rewards system)
      reward_referrer(link.referrer_id, link.source, user_id)

      {:ok, updated_link, event}
    else
      {:error, :link_not_found}
    end
  end

  @doc """
  Gets attribution stats for a user's links.
  """
  def get_user_attribution_stats(user_id, opts \\ []) do
    time_period = opts[:days] || 30
    cutoff = DateTime.add(DateTime.utc_now(), -time_period * 24 * 60 * 60, :second)

    from(l in AttributionLink,
      where: l.referrer_id == ^user_id and l.inserted_at > ^cutoff,
      select: %{
        total_links: count(l.id),
        total_clicks: sum(l.click_count),
        unique_clicks: sum(l.unique_clicks),
        total_conversions: sum(l.conversion_count)
      }
    )
    |> Repo.one()
    |> case do
      nil ->
        %{total_links: 0, total_clicks: 0, unique_clicks: 0, total_conversions: 0}

      stats ->
        Map.merge(stats, %{
          click_through_rate: calculate_ctr(stats.unique_clicks, stats.total_clicks),
          conversion_rate: calculate_conversion_rate(stats.total_conversions, stats.unique_clicks)
        })
    end
  end

  @doc """
  Gets top performing links for a user.
  """
  def get_top_links(user_id, limit \\ 10) do
    from(l in AttributionLink,
      where: l.referrer_id == ^user_id,
      order_by: [desc: l.conversion_count, desc: l.unique_clicks],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets attribution breakdown by source.
  """
  def get_attribution_by_source(user_id, days \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    from(l in AttributionLink,
      where: l.referrer_id == ^user_id and l.inserted_at > ^cutoff,
      group_by: l.source,
      select: %{
        source: l.source,
        links: count(l.id),
        clicks: sum(l.click_count),
        conversions: sum(l.conversion_count)
      }
    )
    |> Repo.all()
  end

  # Private helpers

  defp has_recent_click?(link_id, device_fingerprint) do
    # Check for clicks in last 24 hours from same device
    cutoff = DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second)

    from(e in AttributionEvent,
      where: e.link_id == ^link_id and
             e.device_fingerprint == ^device_fingerprint and
             e.inserted_at > ^cutoff
    )
    |> Repo.exists?()
  end

  defp calculate_ctr(unique_clicks, total_clicks) when is_nil(unique_clicks) or is_nil(total_clicks), do: 0.0
  defp calculate_ctr(_unique_clicks, 0), do: 0.0
  defp calculate_ctr(unique_clicks, total_clicks) do
    Float.round(unique_clicks / total_clicks * 100, 2)
  end

  defp calculate_conversion_rate(conversions, clicks) when is_nil(conversions) or is_nil(clicks), do: 0.0
  defp calculate_conversion_rate(_conversions, 0), do: 0.0
  defp calculate_conversion_rate(conversions, clicks) do
    Float.round(conversions / clicks * 100, 2)
  end

  defp reward_referrer(referrer_id, source, referred_user_id) do
    # In production, integrate with XPContext or rewards system
    Logger.info("Rewarding referrer #{referrer_id} for #{source} conversion: user #{referred_user_id}")

    # Example: Grant XP based on source
    # xp_amount = case source do
    #   "buddy_challenge" -> 50
    #   "results_rally" -> 75
    #   "parent_share" -> 100
    #   _ -> 25
    # end
    # XPContext.grant_xp(referrer_id, xp_amount, :referral_conversion)
  end
end
