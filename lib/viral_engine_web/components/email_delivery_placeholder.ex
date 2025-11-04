defmodule ViralEngineWeb.Components.EmailDeliveryPlaceholder do
  use Phoenix.Component

  @moduledoc """
  Placeholder component for email delivery functionality.
  Displays a "Coming Soon" badge and disclaimer for email features.
  """

  attr :class, :string, default: ""

  def coming_soon_badge(assigns) do
    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800 #{@class}"}>
      🚧 Coming Soon
    </span>
    """
  end

  attr :feature_name, :string, required: true

  def email_disclaimer(assigns) do
    ~H"""
    <div class="bg-blue-50 border-l-4 border-blue-400 p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-blue-700">
            <strong>Note:</strong> {@feature_name} is currently in development. Email delivery will be available once integrated with SendGrid/Swoosh.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
