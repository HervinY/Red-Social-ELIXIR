defmodule RedSocial.SocialCore do
  @moduledoc """
  The SocialCore context.
  Contains business logic for the social network.
  """

  import Ecto.Query, warn: false
  alias RedSocial.Repo
  alias RedSocial.Accounts.User
  alias RedSocial.Social.Relationship
  alias RedSocial.Content.{Post, Interaction, Hashtag, PostHashtag}

  # --- Users & Companies ---

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  # --- Relationships ---

  def follow(%User{} = follower, %User{} = target) do
    %Relationship{}
    |> Relationship.changeset(%{type: "follow"})
    |> Ecto.Changeset.put_assoc(:source, follower)
    |> Ecto.Changeset.put_assoc(:target, target)
    |> Repo.insert()
  end

  def block(%User{} = blocker, %User{} = target) do
    %Relationship{}
    |> Relationship.changeset(%{type: "block"})
    |> Ecto.Changeset.put_assoc(:source, blocker)
    |> Ecto.Changeset.put_assoc(:target, target)
    |> Repo.insert()
  end

  def recommend(%User{} = source, %User{} = target) do
    %Relationship{}
    |> Relationship.changeset(%{type: "recommend"})
    |> Ecto.Changeset.put_assoc(:source, source)
    |> Ecto.Changeset.put_assoc(:target, target)
    |> Repo.insert()
  end

  @doc """
  Creates an employment relationship (person works at company).
  """
  def employ(%User{type: "company"} = company, %User{type: "person"} = employee) do
    %Relationship{}
    |> Relationship.changeset(%{type: "employment"})
    |> Ecto.Changeset.put_assoc(:source, employee)
    |> Ecto.Changeset.put_assoc(:target, company)
    |> Repo.insert()
  end

  @doc """
  Creates a customer relationship (person is customer of company).
  """
  def add_customer(%User{type: "company"} = company, %User{type: "person"} = customer) do
    %Relationship{}
    |> Relationship.changeset(%{type: "customer"})
    |> Ecto.Changeset.put_assoc(:source, customer)
    |> Ecto.Changeset.put_assoc(:target, company)
    |> Repo.insert()
  end

  @doc """
  Checks if two users are friends (mutual following).
  """
  def is_friend?(%User{} = user1, %User{} = user2) do
    follows_query =
      from r in Relationship,
        where: r.source_id == ^user1.id and r.target_id == ^user2.id and r.type == "follow"

    followed_by_query =
      from r in Relationship,
        where: r.source_id == ^user2.id and r.target_id == ^user1.id and r.type == "follow"

    Repo.exists?(follows_query) and Repo.exists?(followed_by_query)
  end

  @doc """
  Gets all friends of a user (mutual followers).
  """
  def get_friends(%User{} = user) do
    # Get users I follow
    following_ids =
      from(r in Relationship,
        where: r.source_id == ^user.id and r.type == "follow",
        select: r.target_id
      )
      |> Repo.all()

    # Get users who follow me
    follower_ids =
      from(r in Relationship,
        where: r.target_id == ^user.id and r.type == "follow",
        select: r.source_id
      )
      |> Repo.all()

    # Intersection = mutual friends
    mutual_ids = Enum.filter(following_ids, fn id -> id in follower_ids end)

    from(u in User, where: u.id in ^mutual_ids)
    |> Repo.all()
  end

  # --- Posts ---

  @doc """
  Creates a post and automatically extracts hashtags from content.
  """
  def create_post(%User{} = author, attrs \\ %{}) do
    result =
      %Post{}
      |> Post.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:author, author)
      |> Repo.insert()

    case result do
      {:ok, post} ->
        # Extract and associate hashtags
        extract_and_associate_hashtags(post)
        {:ok, Repo.preload(post, [:hashtags, :author, :interactions])}

      error ->
        error
    end
  end

  defp extract_and_associate_hashtags(%Post{} = post) do
    # Extract hashtags from content using regex
    hashtag_names =
      ~r/#(\w+)/
      |> Regex.scan(post.content)
      |> Enum.map(fn [_, tag] -> String.downcase(tag) end)
      |> Enum.uniq()

    # Create or get existing hashtags and associate them
    Enum.each(hashtag_names, fn name ->
      hashtag =
        case Repo.get_by(Hashtag, name: name) do
          nil -> Repo.insert!(%Hashtag{name: name})
          existing -> existing
        end

      # Create association if it doesn't exist
      Repo.insert(%PostHashtag{post_id: post.id, hashtag_id: hashtag.id},
        on_conflict: :nothing
      )
    end)
  end

  def list_posts do
    Repo.all(Post) |> Repo.preload([:author, :hashtags, :interactions])
  end

  # --- Interactions ---

  def like(%User{} = user, %Post{} = post) do
    create_interaction(user, post, "like")
  end

  def dislike(%User{} = user, %Post{} = post) do
    create_interaction(user, post, "dislike")
  end

  def repost(%User{} = user, %Post{} = post) do
    create_interaction(user, post, "repost")
  end

  defp create_interaction(user, post, type) do
    %Interaction{}
    |> Interaction.changeset(%{type: type})
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Ecto.Changeset.put_assoc(:post, post)
    |> Repo.insert()
  end

  # --- Visibility Engine (The Core Logic) ---

  @doc """
  Gets the feed for a user based on the "Degree 2" logic.
  Visible:
  1. Posts from people I follow (Degree 1).
  2. Posts from people followed by people I follow (Degree 2).
  3. Exclude posts from people I have blocked or who have blocked me.
  """
  def get_feed_for(%User{} = user) do
    # 1. Get IDs of people I follow (Degree 1)
    degree_1_query =
      from r in Relationship,
        where: r.source_id == ^user.id and r.type == "follow",
        select: r.target_id

    # 2. Get IDs of people followed by degree 1 (Degree 2)
    degree_2_query =
      from r in Relationship,
        where: r.source_id in subquery(degree_1_query) and r.type == "follow",
        select: r.target_id

    # 3. Get IDs of blocked users (I blocked them OR they blocked me)
    blocked_ids_query =
      from r in Relationship,
        where:
          (r.source_id == ^user.id and r.type == "block") or
            (r.target_id == ^user.id and r.type == "block"),
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            r.source_id,
            ^user.id,
            r.target_id,
            r.source_id
          )

    # Combine IDs: Degree 1 + Degree 2 + Self (optional, usually good to see own posts)
    # And filter out blocked
    
    # Note: SQLite doesn't support UNION ALL in subqueries easily in older Ecto versions, 
    # but let's try a composable approach.
    
    # Actually, let's just get the posts where author_id is in the set.
    
    Post
    |> where([p], p.author_id in subquery(degree_1_query) or p.author_id in subquery(degree_2_query) or p.author_id == ^user.id)
    |> where([p], p.author_id not in subquery(blocked_ids_query))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:author, :hashtags, :interactions])
    |> Repo.all()
  end

  # --- Analytics ---

  def get_top_companies_by_likes do
    # Companies are Users with type "company"
    # Count "like" interactions on posts authored by companies
    from(u in User,
      join: p in assoc(u, :posts),
      join: i in assoc(p, :interactions),
      where: u.type == "company" and i.type == "like",
      group_by: u.id,
      select: {u, count(i.id)},
      order_by: [desc: count(i.id)],
      limit: 10
    )
    |> Repo.all()
  end

  def get_trending_hashtags do
    from(h in Hashtag,
      join: ph in PostHashtag, on: ph.hashtag_id == h.id,
      group_by: h.id,
      select: {h, count(ph.post_id)},
      order_by: [desc: count(ph.post_id)],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Gets the most loyal customers for a company (users who liked their posts the most).
  """
  def get_most_loyal_customers(%User{type: "company"} = company) do
    from(u in User,
      join: i in Interaction,
      on: i.user_id == u.id,
      join: p in Post,
      on: i.post_id == p.id,
      where: p.author_id == ^company.id and i.type == "like" and u.type == "person",
      group_by: u.id,
      select: {u, count(i.id)},
      order_by: [desc: count(i.id)],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Gets a complete ranking of companies by engagement score:
  Score = Likes - Dislikes + (Recommendations * 2)
  """
  def get_companies_ranking do
    companies = from(u in User, where: u.type == "company") |> Repo.all()

    companies
    |> Enum.map(fn company ->
      # Count likes
      likes =
        from(i in Interaction,
          join: p in Post,
          on: i.post_id == p.id,
          where: p.author_id == ^company.id and i.type == "like",
          select: count(i.id)
        )
        |> Repo.one() || 0

      # Count dislikes
      dislikes =
        from(i in Interaction,
          join: p in Post,
          on: i.post_id == p.id,
          where: p.author_id == ^company.id and i.type == "dislike",
          select: count(i.id)
        )
        |> Repo.one() || 0

      # Count recommendations received
      recommendations =
        from(r in Relationship,
          where: r.target_id == ^company.id and r.type == "recommend",
          select: count(r.id)
        )
        |> Repo.one() || 0

      score = likes - dislikes + recommendations * 2

      {company, %{likes: likes, dislikes: dislikes, recommendations: recommendations, score: score}}
    end)
    |> Enum.sort_by(fn {_company, stats} -> stats.score end, :desc)
  end

  @doc """
  Gets hashtag statistics including top and bottom posts.
  """
  def get_hashtag_stats(hashtag_name) do
    hashtag = Repo.get_by(Hashtag, name: String.downcase(hashtag_name))

    if hashtag do
      # Get all posts with this hashtag
      posts =
        from(p in Post,
          join: ph in PostHashtag,
          on: ph.post_id == p.id,
          where: ph.hashtag_id == ^hashtag.id,
          preload: [:author, :interactions]
        )
        |> Repo.all()

      # Calculate engagement for each post (likes - dislikes)
      posts_with_engagement =
        Enum.map(posts, fn post ->
          likes = Enum.count(post.interactions, fn i -> i.type == "like" end)
          dislikes = Enum.count(post.interactions, fn i -> i.type == "dislike" end)
          engagement = likes - dislikes
          {post, engagement}
        end)

      top_posts = Enum.sort_by(posts_with_engagement, fn {_post, eng} -> eng end, :desc) |> Enum.take(5)
      bottom_posts = Enum.sort_by(posts_with_engagement, fn {_post, eng} -> eng end, :asc) |> Enum.take(5)

      %{
        hashtag: hashtag,
        total_posts: length(posts),
        top_posts: top_posts,
        bottom_posts: bottom_posts
      }
    else
      nil
    end
  end

  @doc """
  Gets all hashtag statistics (trending with top posts).
  """
  def get_all_hashtags_stats do
    hashtags = Repo.all(Hashtag)

    Enum.map(hashtags, fn hashtag ->
      stats = get_hashtag_stats(hashtag.name)
      {hashtag, stats}
    end)
    |> Enum.filter(fn {_h, stats} -> stats != nil end)
    |> Enum.sort_by(fn {_h, stats} -> stats.total_posts end, :desc)
  end

  @doc """
  Gets all posts with a specific hashtag.
  """
  def get_posts_by_hashtag(hashtag_name) do
    hashtag = Repo.get_by(Hashtag, name: String.downcase(hashtag_name))

    if hashtag do
      from(p in Post,
        join: ph in PostHashtag,
        on: ph.post_id == p.id,
        where: ph.hashtag_id == ^hashtag.id,
        preload: [:author, :interactions, :hashtags],
        order_by: [desc: p.inserted_at]
      )
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Gets all users who have posted with a specific hashtag.
  """
  def get_users_by_hashtag(hashtag_name) do
    hashtag = Repo.get_by(Hashtag, name: String.downcase(hashtag_name))

    if hashtag do
      from(u in User,
        join: p in Post,
        on: p.author_id == u.id,
        join: ph in PostHashtag,
        on: ph.post_id == p.id,
        where: ph.hashtag_id == ^hashtag.id,
        distinct: true,
        select: u
      )
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Calculates the influence network for a user up to N degrees.
  Returns a map with each degree and the users at that level.
  """
  def get_influence_network(%User{} = user, depth: max_depth) do
    get_influence_network_recursive(user.id, max_depth, 1, %{0 => [user.id]}, MapSet.new([user.id]))
  end

  defp get_influence_network_recursive(_user_id, max_depth, current_depth, network, _visited)
       when current_depth > max_depth do
    # Convert to user structs and return
    network
    |> Enum.map(fn {degree, ids} ->
      users = from(u in User, where: u.id in ^ids) |> Repo.all()
      {degree, users}
    end)
    |> Enum.into(%{})
  end

  defp get_influence_network_recursive(user_id, max_depth, current_depth, network, visited) do
    # Get IDs from previous level
    previous_level_ids = Map.get(network, current_depth - 1, [])

    # Get followers of previous level (people who follow them)
    next_level_ids =
      from(r in Relationship,
        where: r.target_id in ^previous_level_ids and r.type == "follow",
        select: r.source_id
      )
      |> Repo.all()
      |> Enum.uniq()
      |> Enum.reject(fn id -> MapSet.member?(visited, id) end)

    if Enum.empty?(next_level_ids) do
      # No more connections, return current network
      network
      |> Enum.map(fn {degree, ids} ->
        users = from(u in User, where: u.id in ^ids) |> Repo.all()
        {degree, users}
      end)
      |> Enum.into(%{})
    else
      new_visited = Enum.reduce(next_level_ids, visited, fn id, acc -> MapSet.put(acc, id) end)
      new_network = Map.put(network, current_depth, next_level_ids)

      get_influence_network_recursive(
        user_id,
        max_depth,
        current_depth + 1,
        new_network,
        new_visited
      )
    end
  end
end
