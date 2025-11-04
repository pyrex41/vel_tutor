defmodule ViralEngine.NotificationSystem do
  @moduledoc """
  Notification system for sending alerts via email, webhooks, and in-app notifications.
  """

  require Logger
  alias ViralEngine.{PubSub, AuditLogContext}

  @doc """
  Sends notifications for an alert via all configured channels.
  """
  def notify_alert(alert) do
    Logger.info("Sending notifications for alert: #{alert.id}")

    # Send email notification
    send_email_notification(alert)

    # Send webhook notifications
    send_webhook_notifications(alert)

    # Send in-app notification
    send_in_app_notification(alert)
  end

  # Private functions

  defp send_email_notification(alert) do
    # In a real implementation, you'd use Bamboo or similar
    # For now, just log the email that would be sent
    email_content = """
    Alert Notification

    Metric Type: #{alert.metric_type}
    Value: #{alert.value}
    Threshold: #{alert.threshold}
    Status: #{alert.status}

    Details: #{Jason.encode!(alert.details)}

    This is an automated alert from the Viral Engine monitoring system.
    """

    Logger.info("Email notification would be sent: #{email_content}")

    # Log to audit system
    AuditLogContext.log_system_event("alert_notification_sent", %{
      alert_id: alert.id,
      channel: "email",
      recipient: Application.get_env(:viral_engine, :notifications)[:email_recipients] || [],
      content: email_content
    })

    # TODO: Implement actual email sending with Bamboo
    # ViralEngine.Mailer.deliver_alert_email(alert)
  end

  defp send_webhook_notifications(alert) do
    # Get configured webhook URLs from config
    webhook_urls = Application.get_env(:viral_engine, :alert_webhooks, [])

    Enum.each(webhook_urls, fn url ->
      send_webhook_notification(url, alert)
    end)
  end

  defp send_webhook_notification(url, alert) do
    payload = %{
      alert_id: alert.id,
      metric_type: alert.metric_type,
      value: alert.value,
      threshold: alert.threshold,
      status: alert.status,
      details: alert.details,
      triggered_at: alert.inserted_at
    }

    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "ViralEngine/1.0"}
    ]

    case Finch.build(:post, url, headers, Jason.encode!(payload))
         |> Finch.request(ViralEngine.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 ->
        Logger.info("Webhook notification sent successfully to #{url}")

        # Log successful webhook delivery
        AuditLogContext.log_system_event("alert_notification_sent", %{
          alert_id: alert.id,
          channel: "webhook",
          url: url,
          status: status,
          success: true
        })

      {:ok, %Finch.Response{status: status}} ->
        Logger.warning("Webhook notification failed with status #{status} for #{url}")

        # Log failed webhook delivery
        AuditLogContext.log_system_event("alert_notification_failed", %{
          alert_id: alert.id,
          channel: "webhook",
          url: url,
          status: status,
          success: false
        })

      {:error, reason} ->
        Logger.error("Webhook notification error for #{url}: #{inspect(reason)}")

        # Log webhook error
        AuditLogContext.log_system_event("alert_notification_failed", %{
          alert_id: alert.id,
          channel: "webhook",
          url: url,
          error: inspect(reason),
          success: false
        })
    end
  end

  defp send_in_app_notification(alert) do
    # Broadcast to Phoenix channels for real-time in-app notifications
    payload = %{
      type: "alert",
      alert_id: alert.id,
      metric_type: alert.metric_type,
      value: alert.value,
      threshold: alert.threshold,
      message: "Alert triggered: #{alert.metric_type} anomaly detected"
    }

    # Broadcast to all connected clients
    Phoenix.PubSub.broadcast(ViralEngine.PubSub, "alerts", payload)

    Logger.info("In-app notification broadcasted for alert: #{alert.id}")

    # Log to audit system
    AuditLogContext.log_system_event("alert_notification_sent", %{
      alert_id: alert.id,
      channel: "in_app",
      broadcast_topic: "alerts",
      payload: payload
    })
  end
end
