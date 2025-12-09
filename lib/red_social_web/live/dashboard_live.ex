defmodule RedSocialWeb.DashboardLive do
  use RedSocialWeb, :live_view
  alias RedSocial.SocialCore
  alias RedSocial.Repo

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
      |> assign(:current_user, nil)
      |> assign(:feed, [])
      |> assign(:feed_filter, "all")
      |> assign(:all_users_list, [])
      |> assign(:user_stats, nil)
      |> assign(:following_list, [])
      |> assign(:recommendations, [])
      |> assign(:form, to_form(%{"content" => ""}))

    {:ok, socket}
  end

  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user = SocialCore.get_user!(user_id)
    feed = apply_feed_filter(user, socket.assigns.feed_filter)

    # Get user stats
    followers_count = SocialCore.count_followers(user)
    following = SocialCore.get_following(user)

    # Get other users for browsing (excluding current user)
    all_users =
      SocialCore.list_users()
      |> Enum.reject(fn u -> u.id == user.id end)

    # Get recommendations if company
    recommendations =
      if user.type == "company" do
        SocialCore.get_recommendations_for_company(user)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:current_user_id, user.id)
     |> assign(:current_user, user)
     |> assign(:feed, feed)
     |> assign(:all_users_list, all_users)
     |> assign(:following_list, following)
     |> assign(:recommendations, recommendations)
     |> assign(:user_stats, %{followers: followers_count})}
  end

  def handle_event("create_post", %{"content" => content}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)

    case SocialCore.create_post(current_user, %{content: content}) do
      {:ok, _post} ->
        # Refresh feed
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
        {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Post created!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error creating post")}
    end
  end

  def handle_event("like_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = Repo.get!(RedSocial.Content.Post, post_id)

    case SocialCore.like(current_user, post) do
      {:ok, _} ->
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
        {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Liked!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Already liked this post")}
    end
  end

  def handle_event("dislike_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = Repo.get!(RedSocial.Content.Post, post_id)

    case SocialCore.dislike(current_user, post) do
      {:ok, _} ->
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
        {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Disliked!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Already disliked this post")}
    end
  end

  def handle_event("repost_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = RedSocial.Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.repost(current_user, post)
    feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Reposted!")}
  end

  def handle_event("unlike_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.unlike(current_user, post)
    feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Like removed!")}
  end

  def handle_event("remove_dislike_post", %{"post_id" => post_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    post = Repo.get!(RedSocial.Content.Post, post_id)
    SocialCore.remove_dislike(current_user, post)
    feed = apply_feed_filter(current_user, socket.assigns.feed_filter)
    {:noreply, socket |> assign(:feed, feed) |> put_flash(:info, "Dislike removed!")}
  end

  def handle_event("follow_user", %{"user_id" => user_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    user_to_follow = SocialCore.get_user!(user_id)

    case SocialCore.follow(current_user, user_to_follow) do
      {:ok, _relationship} ->
        # Refresh data
        following = SocialCore.get_following(current_user)
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)

        {:noreply,
         socket
         |> assign(:following_list, following)
         |> assign(:feed, feed)
         |> put_flash(:info, "Now following #{user_to_follow.username}!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not follow user")}
    end
  end

  def handle_event("unfollow_user", %{"user_id" => user_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    user_to_unfollow = SocialCore.get_user!(user_id)

    case SocialCore.unfollow(current_user, user_to_unfollow) do
      {:ok, _} ->
        # Refresh data
        following = SocialCore.get_following(current_user)
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)

        {:noreply,
         socket
         |> assign(:following_list, following)
         |> assign(:feed, feed)
         |> put_flash(:info, "Unfollowed #{user_to_unfollow.username}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not unfollow user")}
    end
  end

  def handle_event("block_user", %{"user_id" => user_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    user_to_block = SocialCore.get_user!(user_id)

    case SocialCore.block(current_user, user_to_block) do
      {:ok, _relationship} ->
        # Refresh data
        following = SocialCore.get_following(current_user)
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)

        {:noreply,
         socket
         |> assign(:following_list, following)
         |> assign(:feed, feed)
         |> put_flash(:info, "Blocked #{user_to_block.username}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not block user")}
    end
  end

  def handle_event("unblock_user", %{"user_id" => user_id}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    user_to_unblock = SocialCore.get_user!(user_id)

    case SocialCore.unblock(current_user, user_to_unblock) do
      {:ok, _} ->
        # Refresh data
        following = SocialCore.get_following(current_user)
        feed = apply_feed_filter(current_user, socket.assigns.feed_filter)

        {:noreply,
         socket
         |> assign(:following_list, following)
         |> assign(:feed, feed)
         |> put_flash(:info, "Unblocked #{user_to_unblock.username}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not unblock user")}
    end
  end

  def handle_event("change_feed_filter", %{"filter" => filter}, socket) do
    current_user = SocialCore.get_user!(socket.assigns.current_user_id)
    feed = apply_feed_filter(current_user, filter)

    {:noreply,
     socket
     |> assign(:feed_filter, filter)
     |> assign(:feed, feed)}
  end

  # Helper function to apply feed filters
  defp apply_feed_filter(user, "all") do
    SocialCore.get_feed_for(user)
  end

  defp apply_feed_filter(user, "companies") do
    SocialCore.get_feed_for(user)
    |> Enum.filter(fn post -> post.author.type == "company" end)
  end

  defp apply_feed_filter(user, "following") do
    following_ids =
      SocialCore.get_following(user)
      |> Enum.map(fn f -> f.id end)

    SocialCore.get_feed_for(user)
    |> Enum.filter(fn post -> post.author.id in following_ids end)
  end

  defp apply_feed_filter(user, _), do: SocialCore.get_feed_for(user)

  # Helper to check if user already interacted with post
  defp user_interaction(post, user_id, type) do
    Enum.any?(post.interactions, fn i ->
      i.user_id == user_id and i.type == type
    end)
  end

  # Helper to check relationship status
  defp relationship_status(current_user, target_user, following_list) do
    cond do
      current_user.id == target_user.id -> :self
      Enum.any?(following_list, fn f -> f.id == target_user.id end) -> :following
      true -> :not_following
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-purple-50 p-6">
      <div class="max-w-[1800px] mx-auto">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-5xl font-extrabold text-gray-900 mb-2 tracking-tight bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            Red Social Dashboard
          </h1>
          
          <p class="text-gray-600 font-medium">
            Simulate user interactions and explore the social network
          </p>
        </div>
        
        <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
          <!-- Left Sidebar - Analytics -->
          <div class="space-y-6">
            <!-- Analytics Card -->
            <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div class="p-6 border-b border-gray-100 bg-gradient-to-r from-blue-500 to-blue-600">
                <h2 class="text-xl font-bold text-white flex items-center gap-2">
                  <.icon name="hero-chart-bar" class="w-6 h-6" /> Analytics
                </h2>
              </div>
              
              <div class="p-6 space-y-8">
                <div>
                  <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4">
                    Top Companies (by Likes)
                  </h3>
                  
                  <ul class="space-y-3">
                    <%= for {company, count} <- @top_companies do %>
                      <li class="flex items-center justify-between p-3 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg border border-gray-200">
                        <span class="font-bold text-gray-900">{company.name}</span>
                        <span class="px-3 py-1 bg-blue-600 text-white text-sm font-bold rounded-full shadow-sm">
                          {count} ❤️
                        </span>
                      </li>
                    <% end %>
                  </ul>
                </div>
                
                <div>
                  <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4">
                    Trending Hashtags
                  </h3>
                  
                  <div class="flex flex-wrap gap-2">
                    <%= for {hashtag, count} <- @trending_hashtags do %>
                      <span class="px-4 py-2 bg-gradient-to-r from-pink-500 to-purple-500 text-white rounded-full text-sm font-bold shadow-md hover:shadow-lg transition-shadow">
                        #{hashtag.name} <span class="ml-1 opacity-90">({count})</span>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
            <!-- User Selection Card -->
            <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div class="p-6 border-b border-gray-100 bg-gradient-to-r from-green-500 to-green-600">
                <h2 class="text-xl font-bold text-white flex items-center gap-2">
                  <.icon name="hero-user-circle" class="w-6 h-6" /> Select User
                </h2>
              </div>
              
              <div class="p-6">
                <form phx-change="select_user">
                  <select
                    name="user_id"
                    class="w-full rounded-lg border-2 border-gray-300 bg-white text-gray-900 px-4 py-3 shadow-sm focus:border-green-500 focus:ring-2 focus:ring-green-200 font-bold text-base"
                  >
                    <option value="" class="text-gray-500">🎭 Select a user to simulate...</option>
                    
                    <%= for user <- @users do %>
                      <option
                        value={user.id}
                        selected={@current_user_id == user.id}
                        class="text-gray-900 font-bold"
                      >
                        {if user.type == "company", do: "🏢", else: "👤"} {user.username} ({user.type})
                      </option>
                    <% end %>
                  </select>
                </form>
                
                <%= if @current_user do %>
                  <div class="mt-6 p-4 bg-gradient-to-r from-green-50 to-blue-50 rounded-lg border-2 border-green-300">
                    <div class="flex items-center gap-3 mb-3">
                      <div class="w-12 h-12 bg-gradient-to-br from-green-400 to-blue-500 rounded-full flex items-center justify-center text-white text-2xl font-bold shadow-md">
                        {String.first(@current_user.username) |> String.upcase()}
                      </div>
                      
                      <div>
                        <p class="font-bold text-gray-900 text-lg">{@current_user.username}</p>
                        
                        <p class="text-sm text-gray-600 font-medium">
                          {String.capitalize(@current_user.type)}
                        </p>
                      </div>
                    </div>
                    
                    <%= if @user_stats do %>
                      <div class="flex gap-4 text-sm">
                        <div class="flex items-center gap-1">
                          <.icon name="hero-user-group" class="w-4 h-4 text-green-600" />
                          <span class="font-bold text-gray-900">{@user_stats.followers}</span>
                          <span class="text-gray-600">followers</span>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
          <!-- Center - Main Feed -->
          <div class="space-y-6">
            <%= if @current_user_id do %>
              <!-- Create Post -->
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 p-6">
                <h3 class="font-bold text-gray-900 mb-4 text-lg flex items-center gap-2">
                  <.icon name="hero-pencil-square" class="w-5 h-5 text-blue-600" /> Create Post
                </h3>
                
                <form phx-submit="create_post" class="flex gap-2">
                  <input
                    type="text"
                    name="content"
                    placeholder="What's on your mind? Use #hashtags..."
                    class="flex-1 rounded-lg border-2 border-gray-300 bg-white text-gray-900 px-4 py-3 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 placeholder-gray-400 font-medium"
                    required
                  />
                  <button class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-6 py-3 rounded-lg font-bold transition-all shadow-md hover:shadow-xl transform hover:scale-105">
                    Post
                  </button>
                </form>
              </div>
              <!-- Feed Filter -->
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 p-4">
                <form phx-change="change_feed_filter" class="flex gap-2">
                  <label class="flex-1">
                    <input
                      type="radio"
                      name="filter"
                      value="all"
                      checked={@feed_filter == "all"}
                      class="sr-only peer"
                    />
                    <div class="px-4 py-2 text-center rounded-lg border-2 border-gray-300 peer-checked:border-blue-500 peer-checked:bg-blue-50 peer-checked:text-blue-700 font-bold cursor-pointer hover:bg-gray-50 transition-all">
                      All Posts
                    </div>
                  </label>
                  <label class="flex-1">
                    <input
                      type="radio"
                      name="filter"
                      value="companies"
                      checked={@feed_filter == "companies"}
                      class="sr-only peer"
                    />
                    <div class="px-4 py-2 text-center rounded-lg border-2 border-gray-300 peer-checked:border-purple-500 peer-checked:bg-purple-50 peer-checked:text-purple-700 font-bold cursor-pointer hover:bg-gray-50 transition-all">
                      Companies
                    </div>
                  </label>
                  <label class="flex-1">
                    <input
                      type="radio"
                      name="filter"
                      value="following"
                      checked={@feed_filter == "following"}
                      class="sr-only peer"
                    />
                    <div class="px-4 py-2 text-center rounded-lg border-2 border-gray-300 peer-checked:border-green-500 peer-checked:bg-green-50 peer-checked:text-green-700 font-bold cursor-pointer hover:bg-gray-50 transition-all">
                      Following
                    </div>
                  </label>
                </form>
              </div>
              <!-- Feed -->
              <div class="space-y-4">
                <h3 class="font-bold text-gray-900 text-xl flex items-center gap-2">
                  <.icon name="hero-newspaper" class="w-6 h-6 text-blue-600" /> Feed
                  <span class="text-xs font-normal text-gray-500 bg-gray-200 px-3 py-1 rounded-full">
                    {length(@feed)} posts
                  </span>
                </h3>
                
                <div class="space-y-4 max-h-[800px] overflow-y-auto pr-2">
                  <%= for post <- @feed do %>
                    <div class="bg-white border-2 border-gray-200 p-6 rounded-xl shadow-lg hover:shadow-2xl transition-all hover:border-blue-300 transform hover:scale-[1.01]">
                      <!-- Post Header -->
                      <div class="flex justify-between items-start mb-4">
                        <div class="flex items-center gap-3">
                          <div class={"w-10 h-10 rounded-full flex items-center justify-center text-white text-lg font-bold shadow-md #{if post.author.type == "company", do: "bg-gradient-to-br from-purple-400 to-pink-500", else: "bg-gradient-to-br from-blue-400 to-green-500"}"}>
                            {String.first(post.author.username) |> String.upcase()}
                          </div>
                          
                          <div>
                            <span class="font-bold text-gray-900 text-lg">
                              {post.author.username}
                            </span>
                            <span class={"ml-2 text-xs px-2 py-1 rounded-full font-bold #{if post.author.type == "company", do: "bg-purple-100 text-purple-700", else: "bg-green-100 text-green-700"}"}>
                              {if post.author.type == "company", do: "🏢", else: "👤"} {post.author.type}
                            </span>
                          </div>
                        </div>
                        
                        <span class="text-xs text-gray-500 font-medium">
                          {Calendar.strftime(post.inserted_at, "%Y-%m-%d %H:%M")}
                        </span>
                      </div>
                      <!-- Post Content -->
                      <p class="text-gray-800 mb-4 text-base leading-relaxed font-medium">
                        {post.content}
                      </p>
                      <!-- Hashtags -->
                      <%= if length(post.hashtags) > 0 do %>
                        <div class="flex flex-wrap gap-2 mb-4">
                          <%= for hashtag <- post.hashtags do %>
                            <span class="text-xs px-3 py-1 bg-gradient-to-r from-blue-100 to-purple-100 text-blue-700 rounded-full font-bold border border-blue-200">
                              #{hashtag.name}
                            </span>
                          <% end %>
                        </div>
                      <% end %>
                      <!-- Interaction Stats -->
                      <div class="flex items-center gap-6 text-sm text-gray-600 mb-4 pb-4 border-b-2 border-gray-100">
                        <span class="font-bold flex items-center gap-1">
                          <.icon name="hero-heart" class="w-4 h-4 text-red-500" /> {Enum.count(
                            post.interactions,
                            fn i -> i.type == "like" end
                          )}
                        </span>
                        <span class="font-bold flex items-center gap-1">
                          <.icon name="hero-hand-thumb-down" class="w-4 h-4 text-gray-500" /> {Enum.count(
                            post.interactions,
                            fn i -> i.type == "dislike" end
                          )}
                        </span>
                        <span class="font-bold flex items-center gap-1">
                          <.icon name="hero-arrow-path" class="w-4 h-4 text-blue-500" /> {Enum.count(
                            post.interactions,
                            fn i -> i.type == "repost" end
                          )}
                        </span>
                      </div>
                      <!-- Action Buttons -->
                      <div class="grid grid-cols-2 gap-2">
                        <%= if user_interaction(post, @current_user_id, "like") do %>
                          <button
                            phx-click="unlike_post"
                            phx-value-post_id={post.id}
                            class="flex items-center justify-center gap-2 px-4 py-2 bg-gradient-to-r from-red-500 to-pink-500 text-white font-bold rounded-lg transition-all shadow-md hover:shadow-lg transform hover:scale-105"
                          >
                            <.icon name="hero-heart-solid" class="w-5 h-5" /> Liked
                          </button>
                        <% else %>
                          <button
                            phx-click="like_post"
                            phx-value-post_id={post.id}
                            class="flex items-center justify-center gap-2 px-4 py-2 bg-white border-2 border-gray-300 hover:border-red-400 hover:bg-red-50 text-gray-700 hover:text-red-600 font-bold rounded-lg transition-all"
                          >
                            <.icon name="hero-heart" class="w-5 h-5" /> Like
                          </button>
                        <% end %>
                        
                        <%= if user_interaction(post, @current_user_id, "dislike") do %>
                          <button
                            phx-click="remove_dislike_post"
                            phx-value-post_id={post.id}
                            class="flex items-center justify-center gap-2 px-4 py-2 bg-gradient-to-r from-gray-600 to-gray-700 text-white font-bold rounded-lg transition-all shadow-md hover:shadow-lg transform hover:scale-105"
                          >
                            <.icon name="hero-hand-thumb-down-solid" class="w-5 h-5" /> Disliked
                          </button>
                        <% else %>
                          <button
                            phx-click="dislike_post"
                            phx-value-post_id={post.id}
                            class="flex items-center justify-center gap-2 px-4 py-2 bg-white border-2 border-gray-300 hover:border-gray-500 hover:bg-gray-50 text-gray-700 font-bold rounded-lg transition-all"
                          >
                            <.icon name="hero-hand-thumb-down" class="w-5 h-5" /> Dislike
                          </button>
                        <% end %>
                        
                        <button
                          phx-click="repost_post"
                          phx-value-post_id={post.id}
                          class="col-span-2 flex items-center justify-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-bold rounded-lg transition-all shadow-md hover:shadow-lg transform hover:scale-105"
                        >
                          <.icon name="hero-arrow-path" class="w-5 h-5" /> Repost
                        </button>
                      </div>
                    </div>
                  <% end %>
                  
                  <%= if Enum.empty?(@feed) do %>
                    <div class="text-center py-12 bg-white rounded-xl border-2 border-dashed border-gray-300">
                      <.icon name="hero-inbox" class="w-16 h-16 text-gray-400 mx-auto mb-4" />
                      <p class="text-gray-500 font-medium text-lg">No posts visible in this feed</p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 p-12 text-center">
                <.icon name="hero-user-circle" class="w-24 h-24 text-gray-300 mx-auto mb-4" />
                <h3 class="text-2xl font-bold text-gray-900 mb-2">Select a user to start</h3>
                
                <p class="text-gray-600">
                  Choose a user from the left sidebar to simulate their experience
                </p>
              </div>
            <% end %>
          </div>
          <!-- Right Sidebar - Users & Actions -->
          <div class="space-y-6">
            <%= if @current_user_id do %>
              <!-- Users to Follow -->
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
                <div class="p-6 border-b border-gray-100 bg-gradient-to-r from-purple-500 to-pink-600">
                  <h2 class="text-xl font-bold text-white flex items-center gap-2">
                    <.icon name="hero-users" class="w-6 h-6" /> Discover Users
                  </h2>
                </div>
                
                <div class="p-6 space-y-3 max-h-[600px] overflow-y-auto">
                  <%= for user <- @all_users_list do %>
                    <div class="p-4 bg-gradient-to-r from-gray-50 to-gray-100 rounded-lg border border-gray-200 hover:shadow-md transition-shadow">
                      <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center gap-3">
                          <div class={"w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-bold shadow-md #{if user.type == "company", do: "bg-gradient-to-br from-purple-400 to-pink-500", else: "bg-gradient-to-br from-blue-400 to-green-500"}"}>
                            {String.first(user.username) |> String.upcase()}
                          </div>
                          
                          <div>
                            <p class="font-bold text-gray-900">{user.username}</p>
                            
                            <p class="text-xs text-gray-600 font-medium">
                              {if user.type == "company", do: "🏢", else: "👤"} {String.capitalize(
                                user.type
                              )}
                            </p>
                          </div>
                        </div>
                      </div>
                      
                      <%= case relationship_status(@current_user, user, @following_list) do %>
                        <% :following -> %>
                          <div class="grid grid-cols-2 gap-2">
                            <button
                              phx-click="unfollow_user"
                              phx-value-user_id={user.id}
                              class="px-3 py-2 bg-gradient-to-r from-blue-500 to-blue-600 text-white font-bold text-sm rounded-lg hover:from-blue-600 hover:to-blue-700 transition-all shadow-md"
                            >
                              ✓ Following
                            </button>
                            <button
                              phx-click="block_user"
                              phx-value-user_id={user.id}
                              class="px-3 py-2 bg-white border-2 border-red-300 text-red-600 font-bold text-sm rounded-lg hover:bg-red-50 transition-all"
                            >
                              Block
                            </button>
                          </div>
                        <% :not_following -> %>
                          <button
                            phx-click="follow_user"
                            phx-value-user_id={user.id}
                            class="w-full px-3 py-2 bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 text-white font-bold text-sm rounded-lg transition-all shadow-md hover:shadow-lg transform hover:scale-105"
                          >
                            + Follow
                          </button>
                        <% :self -> %>
                          <div class="px-3 py-2 bg-gray-200 text-gray-600 font-bold text-sm rounded-lg text-center">
                            This is you
                          </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
              <!-- Company Recommendations -->
              <%= if @current_user.type == "company" and length(@recommendations) > 0 do %>
                <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
                  <div class="p-6 border-b border-gray-100 bg-gradient-to-r from-orange-500 to-red-600">
                    <h2 class="text-xl font-bold text-white flex items-center gap-2">
                      <.icon name="hero-star" class="w-6 h-6" /> Recommendations
                    </h2>
                  </div>
                  
                  <div class="p-6 space-y-3">
                    <%= for user <- @recommendations do %>
                      <div class="p-4 bg-gradient-to-r from-orange-50 to-red-50 rounded-lg border-2 border-orange-200">
                        <div class="flex items-center gap-3">
                          <div class="w-10 h-10 bg-gradient-to-br from-orange-400 to-red-500 rounded-full flex items-center justify-center text-white text-sm font-bold shadow-md">
                            {String.first(user.username) |> String.upcase()}
                          </div>
                          
                          <div class="flex-1">
                            <p class="font-bold text-gray-900">{user.username}</p>
                            
                            <p class="text-xs text-gray-600 font-medium">Recommended for you</p>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
