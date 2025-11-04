defmodule ViralEngineWeb.PresenceGlobalComponent do
  use ViralEngineWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="global-presence">
      Online Users: <%= length(Map.values(@presence)) %>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, assign(socket, presence: assigns.global_presence)}
  end
end
