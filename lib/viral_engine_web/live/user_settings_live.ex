defmodule ViralEngineWeb.UserSettingsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    changeset = Accounts.change_user_registration(user)
    {:ok, assign(socket, changeset: changeset, triggers: [])}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_registration(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        # If presence_opt_out changed, handle untracking
        if user_params["presence_opt_out"] != nil do
          opt_out = user_params["presence_opt_out"] == "true"

          if opt_out != user.presence_opt_out do
            if opt_out do
              # User opted out - untrack from all presence
              ViralEngine.Presence.untrack(self(), "global_users", user.id)
              # Example subject
              ViralEngine.Presence.untrack(self(), "subject:practice", user.id)

              Phoenix.PubSub.broadcast(
                ViralEngine.PubSub,
                "presence:global",
                {:presence_diff, {"global_users", nil}}
              )
            else
              # Opted in - re-track
              ViralEngine.Presence.track_global(self(), user.id, %{name: user.name || "Anonymous"})
            end
          end
        end

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully.")
         |> assign(triggers: [])}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto">
      <h1 class="text-2xl font-bold mb-6">User Settings</h1>
      
      <.simple_form 
        for={@changeset} 
        id="user_settings_form" 
        phx-submit="save" 
        phx-change="validate">
        
        <.input field={@changeset[:email]} type="email" label="Email" />
        <.input field={@changeset[:name]} type="text" label="Name" />
        
        <div class="field">
          <.input 
            type="checkbox" 
            field={@changeset[:presence_opt_out]} 
            label="Opt out of presence tracking (hide from other users)" 
            checked={@changeset.data.presence_opt_out} />
          <p class="text-sm text-gray-600 mt-1">
            When enabled, you won't appear in online user lists or session attendee lists.
          </p>
        </div>
        
        <:actions>
          <.button phx-disable-with="Saving...">Save Settings</.button>
        </:actions>
      </.simple_form>
      
      <div class="mt-6 p-4 bg-yellow-50 rounded-lg">
        <h3 class="font-medium text-yellow-800 mb-2">Current Status</h3>
        <p class="text-sm text-yellow-700">
          Status: <%= @changeset.data.presence_status || "offline" %>
          <%= if @changeset.data.last_seen_at do %>
            Last seen: <%= Calendar.strftime(@changeset.data.last_seen_at, "%b %d, %Y %H:%M") %>
          <% end %>
        </p>
      </div>
    </div>
    """
  end
end
