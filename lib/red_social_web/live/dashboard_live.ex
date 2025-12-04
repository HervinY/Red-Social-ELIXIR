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
    feed = SocialCore.get_feed_for(current_user)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Liked!")}
  end

  def handle_event("dislike_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = RedSocial.Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.dislike(current_user, post)
    feed = SocialCore.get_feed_for(current_user)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Disliked!")}
  end

  def handle_event("repost_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = RedSocial.Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.repost(current_user, post)
    feed = SocialCore.get_feed_for(current_user)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Reposted!")}
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
                <label class="block text-sm font-bold text-gray-900 mb-2">Simulate as User:</label>
                <form phx-change="select_user">
                  <select name="user_id" class="w-full rounded-lg border-2 border-gray-300 bg-white text-gray-900 px-4 py-2.5 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 font-medium">
                    <option value="" class="text-gray-500">Select a user...</option>
                    <%= for user <- @users do %>
                      <option value={user.id} selected={@current_user_id == user.id} class="text-gray-900 font-medium">
                        <%= user.username %> (<%= user.type %>)
                      </option>
                    <% end %>
                  </select>
                </form>
              </div>

              <%= if @current_user_id do %>
                <div class="mb-8 bg-blue-50 p-5 rounded-lg border-2 border-blue-200">
                  <h3 class="font-bold text-gray-900 mb-3 text-lg">Create Post</h3>
                  <form phx-submit="create_post" class="flex gap-2">
                    <input
                      type="text"
                      name="content"
                      placeholder="What's on your mind? Use #hashtags"
                      class="flex-1 rounded-lg border-2 border-gray-300 bg-white text-gray-900 px-4 py-2.5 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 placeholder-gray-500"
                      required
                    />
                    <button class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2.5 rounded-lg font-bold transition-colors shadow-md hover:shadow-lg">
                      Post
                    </button>
                  </form>
                </div>

                <div>
                  <h3 class="font-bold text-gray-900 mb-4 flex items-center gap-2">
                    Feed (Degree 2)
                    <span class="text-xs font-normal text-gray-500 bg-gray-200 px-2 py-0.5 rounded-full">Visible posts</span>
                  </h3>
                  <div class="space-y-4 max-h-[500px] overflow-y-auto pr-2">
                    <%= for post <- @feed do %>
                      <div class="bg-white border-2 border-gray-200 p-5 rounded-lg shadow-md hover:shadow-xl transition-all hover:border-blue-300">
                        <div class="flex justify-between items-start mb-3">
                          <div>
                            <span class="font-bold text-gray-900 text-lg"><%= post.author.username %></span>
                            <span class={"ml-2 text-xs px-2 py-1 rounded-full #{if post.author.type == "company", do: "bg-purple-100 text-purple-700", else: "bg-green-100 text-green-700"}"}>
                              <%= post.author.type %>
                            </span>
                          </div>
                          <span class="text-xs text-gray-500 font-medium"><%= Calendar.strftime(post.inserted_at, "%Y-%m-%d %H:%M") %></span>
                        </div>
                        <p class="text-gray-800 mb-4 text-base leading-relaxed"><%= post.content %></p>

                        <!-- Hashtags -->
                        <%= if length(post.hashtags) > 0 do %>
                          <div class="flex flex-wrap gap-2 mb-3">
                            <%= for hashtag <- post.hashtags do %>
                              <span class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded-full font-medium">
                                #<%= hashtag.name %>
                              </span>
                            <% end %>
                          </div>
                        <% end %>

                        <!-- Interaction Stats -->
                        <div class="flex items-center gap-4 text-sm text-gray-600 mb-3 pb-3 border-b border-gray-200">
                          <span class="font-medium">
                            <%= Enum.count(post.interactions, fn i -> i.type == "like" end) %> likes
                          </span>
                          <span class="font-medium">
                            <%= Enum.count(post.interactions, fn i -> i.type == "dislike" end) %> dislikes
                          </span>
                          <span class="font-medium">
                            <%= Enum.count(post.interactions, fn i -> i.type == "repost" end) %> reposts
                          </span>
                        </div>

                        <!-- Action Buttons -->
                        <div class="flex items-center gap-2">
                          <button
                            phx-click="like_post"
                            phx-value-post_id={post.id}
                            class="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-green-50 hover:bg-green-100 text-green-700 font-bold rounded-lg transition-colors border-2 border-green-200 hover:border-green-300"
                          >
                            <.icon name="hero-heart" class="w-5 h-5" />
                            Like
                          </button>
                          <button
                            phx-click="dislike_post"
                            phx-value-post_id={post.id}
                            class="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-red-50 hover:bg-red-100 text-red-700 font-bold rounded-lg transition-colors border-2 border-red-200 hover:border-red-300"
                          >
                            <.icon name="hero-hand-thumb-down" class="w-5 h-5" />
                            Dislike
                          </button>
                          <button
                            phx-click="repost_post"
                            phx-value-post_id={post.id}
                            class="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-blue-50 hover:bg-blue-100 text-blue-700 font-bold rounded-lg transition-colors border-2 border-blue-200 hover:border-blue-300"
                          >
                            <.icon name="hero-arrow-path" class="w-5 h-5" />
                            Repost
                          </button>
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
