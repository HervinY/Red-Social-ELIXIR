defmodule RedSocialWeb.DashboardLive do
  use RedSocialWeb, :live_view
  alias RedSocial.SocialCore
  alias RedSocial.Accounts

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates if we implement PubSub later
    end

    socket =
      socket
      |> assign(:top_companies, SocialCore.get_top_companies_by_likes())
      |> assign(:trending_hashtags, SocialCore.get_trending_hashtags())
      |> assign(:users, SocialCore.list_users())
      |> assign(:current_user_id, nil)
      |> assign(:feed, [])
      |> assign(:form, to_form(%{"content" => ""}))

    {:ok, socket}
  end

  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user = SocialCore.get_user!(user_id)
    feed = SocialCore.get_feed_for(user)
    
    {:noreply,
     socket
     |> assign(:current_user_id, user.id)
     |> assign(:feed, feed)}
  end

  def handle_event("create_post", %{"content" => content}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    case SocialCore.create_post(current_user, %{content: content}) do
      {:ok, _post} ->
        # Refresh feed
        feed = SocialCore.get_feed_for(current_user)
        {:noreply, assign(socket, :feed, feed)}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error creating post")}
    end
  end

  def handle_event("like_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = RedSocial.Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.like(current_user, post)
    {:noreply, put_flash(socket, :info, "Liked!")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-8">
      <div class="max-w-7xl mx-auto">
        <h1 class="text-4xl font-extrabold text-gray-900 mb-8 tracking-tight">Red Social Dashboard</h1>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Analytics Section -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="p-6 border-b border-gray-100 bg-gray-50">
              <h2 class="text-xl font-bold text-gray-800 flex items-center gap-2">
                <.icon name="hero-chart-bar" class="w-5 h-5 text-blue-600" />
                Analytics
              </h2>
            </div>
            
            <div class="p-6 space-y-8">
              <div>
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4">Top Companies (by Likes)</h3>
                <ul class="space-y-3">
                  <%= for {company, count} <- @top_companies do %>
                    <li class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <span class="font-medium text-gray-900"><%= company.name %></span>
                      <span class="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-bold rounded-full"><%= count %> likes</span>
                    </li>
                  <% end %>
                </ul>
              </div>

              <div>
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4">Trending Hashtags</h3>
                <div class="flex flex-wrap gap-2">
                  <%= for {hashtag, count} <- @trending_hashtags do %>
                    <span class="px-3 py-1 bg-pink-100 text-pink-800 rounded-full text-sm font-medium">
                      #<%= hashtag.name %> <span class="ml-1 opacity-75">(<%= count %>)</span>
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <!-- Simulation Section -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
             <div class="p-6 border-b border-gray-100 bg-gray-50">
              <h2 class="text-xl font-bold text-gray-800 flex items-center gap-2">
                <.icon name="hero-user-group" class="w-5 h-5 text-green-600" />
                Simulation
              </h2>
            </div>
            
            <div class="p-6">
              <div class="mb-6">
                <label class="block text-sm font-medium text-gray-700 mb-2">Simulate as User:</label>
                <form phx-change="select_user">
                  <select name="user_id" class="w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500">
                    <option value="">Select a user...</option>
                    <%= for user <- @users do %>
                      <option value={user.id} selected={@current_user_id == user.id}><%= user.username %> (<%= user.type %>)</option>
                    <% end %>
                  </select>
                </form>
              </div>

              <%= if @current_user_id do %>
                <div class="mb-8 bg-gray-50 p-4 rounded-lg border border-gray-200">
                  <h3 class="font-bold text-gray-900 mb-3">Create Post</h3>
                  <form phx-submit="create_post" class="flex gap-2">
                    <input type="text" name="content" placeholder="What's on your mind?" class="flex-1 rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" required />
                    <button class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium transition-colors">Post</button>
                  </form>
                </div>

                <div>
                  <h3 class="font-bold text-gray-900 mb-4 flex items-center gap-2">
                    Feed (Degree 2)
                    <span class="text-xs font-normal text-gray-500 bg-gray-200 px-2 py-0.5 rounded-full">Visible posts</span>
                  </h3>
                  <div class="space-y-4 max-h-[500px] overflow-y-auto pr-2">
                    <%= for post <- @feed do %>
                      <div class="bg-white border border-gray-200 p-4 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                        <div class="flex justify-between items-start mb-2">
                          <span class="font-bold text-gray-900"><%= post.author.username %></span>
                          <span class="text-xs text-gray-500"><%= Calendar.strftime(post.inserted_at, "%Y-%m-%d %H:%M") %></span>
                        </div>
                        <p class="text-gray-700 mb-3"><%= post.content %></p>
                        <div class="flex items-center gap-4 text-sm text-gray-500 border-t pt-3 mt-2">
                          <button phx-click="like_post" phx-value-post_id={post.id} class="flex items-center gap-1 hover:text-red-500 transition-colors">
                            <.icon name="hero-heart" class="w-4 h-4" /> Like
                          </button>
                          <span><%= length(post.interactions) %> interactions</span>
                        </div>
                      </div>
                    <% end %>
                    <%= if Enum.empty?(@feed) do %>
                      <p class="text-center text-gray-500 py-8">No posts visible in this feed.</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
        <div class="mt-8 text-center">
          <a href={~p"/users"} class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-800 font-medium">
            Manage Users <.icon name="hero-arrow-right" class="w-4 h-4" />
          </a>
        </div>
      </div>
    </div>
    """
  end
end
