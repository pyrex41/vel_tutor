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
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Settings</h1>
          <p class="text-muted-foreground">Manage your account preferences</p>
        </div>

        <!-- Account Settings -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 mb-6">
          <h2 class="text-xl font-semibold text-foreground mb-4">Account</h2>

          <.simple_form
            for={@changeset}
            id="user_settings_form"
            phx-submit="save"
            phx-change="validate">

            <div class="space-y-4">
              <.input
                field={@changeset[:email]}
                type="email"
                label="Email"
                class="bg-background border border-input rounded-md px-3 py-2 focus:ring-2 focus:ring-primary"
              />
              <.input
                field={@changeset[:name]}
                type="text"
                label="Name"
                class="bg-background border border-input rounded-md px-3 py-2 focus:ring-2 focus:ring-primary"
              />
            </div>

            <:actions>
              <.button
                phx-disable-with="Saving..."
                class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              >
                Save Settings
              </.button>
            </:actions>
          </.simple_form>
        </div>

        <!-- Privacy Settings -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 mb-6">
          <h2 class="text-xl font-semibold text-foreground mb-4">Privacy</h2>

          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <label class="text-sm font-medium text-foreground">Presence Tracking</label>
                <p class="text-sm text-muted-foreground">
                  Allow others to see when you're online and in study sessions
                </p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="user[presence_opt_out]"
                  value="true"
                  checked={!@changeset.data.presence_opt_out}
                  class="sr-only peer"
                  phx-change="validate"
                />
                <div class="w-11 h-6 bg-secondary peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/25 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>

            <div class="text-sm text-muted-foreground">
              <%= if @changeset.data.presence_opt_out do %>
                You're currently hidden from other users
              <% else %>
                You're visible to other users when online
              <% end %>
            </div>
          </div>
        </div>

        <!-- Status Information -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
          <h2 class="text-xl font-semibold text-foreground mb-4">Status</h2>

          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-sm font-medium text-muted-foreground">Current Status</span>
              <span class="text-sm font-medium text-foreground">
                <%= @changeset.data.presence_status || "offline" %>
              </span>
            </div>

            <%= if @changeset.data.last_seen_at do %>
              <div class="flex justify-between items-center">
                <span class="text-sm font-medium text-muted-foreground">Last Seen</span>
                <span class="text-sm font-medium text-foreground">
                  <%= Calendar.strftime(@changeset.data.last_seen_at, "%b %d, %Y %H:%M") %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
