defmodule ViralEngineWeb.PrepPackLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, PrepPack}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Public prep pack view (can be shared)
    prep_pack =
      from(p in PrepPack,
        where: p.pack_token == ^token
      )
      |> Repo.one()

    if prep_pack do
      # Increment view count
      {:ok, updated_pack} = Repo.update(PrepPack.increment_views(prep_pack))

      socket =
        socket
        |> assign(:prep_pack, updated_pack)
        |> assign(:public_view, true)
        |> assign(:show_share_modal, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Prep pack not found or expired")
       |> redirect(to: "/")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to new prep pack events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:prep_packs")
    end

    # Get user's prep packs
    prep_packs =
      from(p in PrepPack,
        where: p.student_id == ^user.id,
        order_by: [desc: p.inserted_at],
        limit: 10
      )
      |> Repo.all()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:prep_packs, prep_packs)
      |> assign(:selected_pack, nil)
      |> assign(:show_share_modal, false)
      |> assign(:public_view, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("view_pack", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)
    pack = Enum.find(socket.assigns.prep_packs, &(&1.id == pack_id))

    {:noreply, assign(socket, :selected_pack, pack)}
  end

  @impl true
  def handle_event("open_share_modal", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)

    pack =
      if socket.assigns[:selected_pack] && socket.assigns.selected_pack.id == pack_id do
        socket.assigns.selected_pack
      else
        Enum.find(socket.assigns.prep_packs, &(&1.id == pack_id))
      end

    {:noreply,
     socket
     |> assign(:selected_pack, pack)
     |> assign(:show_share_modal, true)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("copy_pack_link", _params, socket) do
    pack = socket.assigns.selected_pack || socket.assigns.prep_pack
    pack_url = prep_pack_url(pack)

    Logger.info("Prep pack link copied: #{pack_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Prep pack link copied! Share with study buddies 📚")}
  end

  @impl true
  def handle_event("share_pack", _params, socket) do
    pack = socket.assigns.selected_pack || socket.assigns.prep_pack

    # Increment share count
    {:ok, updated_pack} = Repo.update(PrepPack.increment_shares(pack))

    Logger.info("Prep pack #{pack.id} shared by student #{pack.student_id}")

    packs =
      if socket.assigns.public_view do
        nil
      else
        # Update pack in list
        Enum.map(socket.assigns.prep_packs, fn p ->
          if p.id == updated_pack.id, do: updated_pack, else: p
        end)
      end

    socket =
      if packs do
        assign(socket, :prep_packs, packs)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> put_flash(:success, "Prep pack shared! 🎉")}
  end

  @impl true
  def handle_event("mark_completed", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)
    pack = Enum.find(socket.assigns.prep_packs, &(&1.id == pack_id))

    if pack do
      {:ok, updated_pack} = Repo.update(PrepPack.mark_completed(pack))

      # Update list
      updated_packs =
        Enum.map(socket.assigns.prep_packs, fn p ->
          if p.id == updated_pack.id, do: updated_pack, else: p
        end)

      {:noreply,
       socket
       |> assign(:prep_packs, updated_packs)
       |> put_flash(:success, "Great job! Prep pack completed! ✅")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:prep_pack_ready, %{prep_pack: prep_pack}}, socket) do
    # New prep pack generated
    updated_packs = [prep_pack | socket.assigns.prep_packs]

    {:noreply,
     socket
     |> assign(:prep_packs, updated_packs)
     |> put_flash(:success, "📚 New prep pack ready! #{prep_pack.pack_name}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-6xl mx-auto">
        <%= if @public_view do %>
          <!-- Public Prep Pack View -->
          <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-8">
            <div class="text-center mb-6">
              <h1 class="text-3xl font-bold text-foreground mb-2"><%= @prep_pack.pack_name %></h1>
              <p class="text-muted-foreground text-lg"><%= @prep_pack.description %></p>
            </div>

            <div class="grid md:grid-cols-3 gap-6 mb-6">
              <div class="text-center">
                <div class="text-2xl font-bold text-foreground"><%= @prep_pack.resource_count %></div>
                <div class="text-sm text-muted-foreground">Resources</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-foreground"><%= @prep_pack.view_count %></div>
                <div class="text-sm text-muted-foreground">Views</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-foreground"><%= @prep_pack.share_count %></div>
                <div class="text-sm text-muted-foreground">Shares</div>
              </div>
            </div>

            <div class="text-center">
              <button
                phx-click="open_share_modal"
                phx-value-pack_id={@prep_pack.id}
                class="inline-flex items-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md transition-colors"
                aria-label="Share this prep pack"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                </svg>
                <span>Share Prep Pack</span>
              </button>
            </div>
          </div>
        <% else %>
          <!-- User Prep Packs View -->
          <div class="text-center mb-8">
            <h1 class="text-3xl font-bold text-foreground mb-2">My Prep Packs</h1>
            <p class="text-muted-foreground">Access your personalized study materials</p>
          </div>

          <%= if length(@prep_packs) > 0 do %>
            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
              <%= for pack <- @prep_packs do %>
                <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 hover:shadow-md transition-shadow">
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-lg font-semibold text-foreground mb-1"><%= pack.pack_name %></h3>
                      <p class="text-sm text-muted-foreground mb-2"><%= pack.description %></p>
                      <div class="flex items-center space-x-2">
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-secondary text-secondary-foreground">
                          <%= pack.resource_count %> resources
                        </span>
                        <%= if pack.completed do %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            Completed
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            In Progress
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <div class="flex flex-col space-y-3">
                    <button
                      phx-click="view_pack"
                      phx-value-pack_id={pack.id}
                      class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
                      aria-label="View prep pack details"
                    >
                      View Pack
                    </button>

                    <div class="flex space-x-2">
                      <button
                        phx-click="open_share_modal"
                        phx-value-pack_id={pack.id}
                        class="flex-1 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-medium px-3 py-2 rounded-md transition-colors text-sm"
                        aria-label="Share this prep pack"
                      >
                        Share
                      </button>

                      <%= if not pack.completed do %>
                        <button
                          phx-click="mark_completed"
                          phx-value-pack_id={pack.id}
                          class="flex-1 bg-green-600 text-white hover:bg-green-700 font-medium px-3 py-2 rounded-md transition-colors text-sm"
                          aria-label="Mark prep pack as completed"
                        >
                          Complete
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <!-- Empty State -->
            <div class="text-center py-12">
              <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-muted mb-4">
                <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-foreground mb-2">No Prep Packs Yet</h3>
              <p class="text-muted-foreground mb-6">Your personalized prep packs will appear here once they're ready.</p>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>

    <!-- Share Modal -->
    <%= if @show_share_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_share_modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="share-modal-title" class="text-xl font-bold text-foreground mb-4">Share Prep Pack</h3>
          <p class="text-muted-foreground mb-6">Help your study buddies prepare too!</p>

          <div class="mb-6">
            <input
              type="text"
              value={prep_pack_url(@selected_pack || @prep_pack)}
              readonly
              class="w-full px-3 py-2 bg-background border border-input rounded-md text-sm"
              aria-label="Prep pack share URL"
            />
          </div>

          <div class="space-y-3">
            <button
              phx-click="copy_pack_link"
              class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              aria-label="Copy prep pack link to clipboard"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>

            <button
              phx-click="share_pack"
              class="w-full flex items-center justify-center space-x-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-medium px-4 py-2 rounded-md transition-colors"
              aria-label="Share prep pack"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
              </svg>
              <span>Share</span>
            </button>

            <button
              phx-click="close_share_modal"
              class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
              aria-label="Close share modal"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Helper functions

  defp prep_pack_url(pack) do
    "#{ViralEngineWeb.Endpoint.url()}/prep/#{pack.pack_token}"
  end
end
