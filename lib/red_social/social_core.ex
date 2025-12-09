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
    # Check if already following
    existing =
      from(r in Relationship,
        where: r.source_id == ^follower.id and r.target_id == ^target.id and r.type == "follow"
      )
      |> Repo.one()

    case existing do
      nil ->
        %Relationship{}
        |> Relationship.changeset(%{type: "follow"})
        |> Ecto.Changeset.put_assoc(:source, follower)
        |> Ecto.Changeset.put_assoc(:target, target)
        |> Repo.insert()

      relationship ->
        {:ok, relationship}
    end
  end

  def block(%User{} = blocker, %User{} = target) do
    # Check if already blocked
    existing =
      from(r in Relationship,
        where: r.source_id == ^blocker.id and r.target_id == ^target.id and r.type == "block"
      )
      |> Repo.one()

    case existing do
      nil ->
        %Relationship{}
        |> Relationship.changeset(%{type: "block"})
        |> Ecto.Changeset.put_assoc(:source, blocker)
        |> Ecto.Changeset.put_assoc(:target, target)
        |> Repo.insert()

      relationship ->
        {:ok, relationship}
    end
  end

  def unfollow(%User{} = follower, %User{} = target) do
    from(r in Relationship,
      where: r.source_id == ^follower.id and r.target_id == ^target.id and r.type == "follow"
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, :deleted}
      {0, _} -> {:error, :not_found}
    end
  end

  def unblock(%User{} = blocker, %User{} = target) do
    from(r in Relationship,
      where: r.source_id == ^blocker.id and r.target_id == ^target.id and r.type == "block"
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, :deleted}
      {0, _} -> {:error, :not_found}
    end
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

  @doc """
  Adds a like to a post. A user can only like a post once.
  Returns {:ok, interaction} if successful, or {:error, reason} if already liked.
  """
  def like(%User{} = user, %Post{} = post) do
    case get_interaction(user, post, "like") do
      nil -> create_interaction(user, post, "like")
      existing -> {:ok, existing}
    end
  end

  @doc """
  Adds a dislike to a post. A user can only dislike a post once.
  Returns {:ok, interaction} if successful, or {:error, reason} if already disliked.
  """
  def dislike(%User{} = user, %Post{} = post) do
    case get_interaction(user, post, "dislike") do
      nil -> create_interaction(user, post, "dislike")
      existing -> {:ok, existing}
    end
  end

  @doc """
  Removes a like from a post.
  """
  def unlike(%User{} = user, %Post{} = post) do
    case get_interaction(user, post, "like") do
      nil -> {:error, "You haven't liked this post"}
      interaction -> Repo.delete(interaction)
    end
  end

  @doc """
  Removes a dislike from a post.
  """
  def remove_dislike(%User{} = user, %Post{} = post) do
    case get_interaction(user, post, "dislike") do
      nil -> {:error, "You haven't disliked this post"}
      interaction -> Repo.delete(interaction)
    end
  end

  defp get_interaction(user, post, type) do
    Repo.get_by(Interaction, user_id: user.id, post_id: post.id, type: type)
  end

  @doc """
  Creates a repost. Rules:
  - A person can only repost a post from someone they follow.
  - A company can repost its own posts or posts from companies it follows.
  """
  def repost(%User{type: "person"} = person, %Post{} = post) do
    # Check if person follows the post author
    follows_query =
      from r in Relationship,
        where: r.source_id == ^person.id and r.target_id == ^post.author_id and r.type == "follow"

    if Repo.exists?(follows_query) do
      # Create new post with reference to original
      %Post{}
      |> Post.changeset(%{
        content: post.content,
        original_post_id: post.id
      })
      |> Ecto.Changeset.put_assoc(:author, person)
      |> Repo.insert()
      |> case do
        {:ok, repost} ->
          # Also create an interaction for tracking
          create_interaction(person, post, "repost")
          {:ok, Repo.preload(repost, [:author, :original_post, :hashtags])}

        error ->
          error
      end
    else
      {:error, "You can only repost posts from people you follow"}
    end
  end

  def repost(%User{type: "company"} = company, %Post{} = post) do
    # Company can repost its own posts or posts from companies it follows
    can_repost =
      post.author_id == company.id or
        Repo.exists?(
          from r in Relationship,
            where:
              r.source_id == ^company.id and r.target_id == ^post.author_id and r.type == "follow"
        )

    if can_repost do
      %Post{}
      |> Post.changeset(%{
        content: post.content,
        original_post_id: post.id
      })
      |> Ecto.Changeset.put_assoc(:author, company)
      |> Repo.insert()
      |> case do
        {:ok, repost} ->
          create_interaction(company, post, "repost")
          {:ok, Repo.preload(repost, [:author, :original_post, :hashtags])}

        error ->
          error
      end
    else
      {:error, "Company can only repost its own posts or posts from companies it follows"}
    end
  end

  defp create_interaction(user, post, type) do
    %Interaction{}
    |> Interaction.changeset(%{type: type})
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Ecto.Changeset.put_assoc(:post, post)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:user_id, :post_id, :type]
    )
  end

  # --- Visibility Engine (The Core Logic) ---

  @doc """
  Gets the feed for a user based on visibility rules:
  1. Posts from companies (visible to ALL members of the network).
  2. Posts from people I follow (Degree 1).
  3. Posts from people followed by people I follow (Degree 2).
  4. Exclude posts from people I have blocked or who have blocked me.
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

    # 4. Get company IDs (their posts are visible to everyone)
    company_ids_query =
      from u in User,
        where: u.type == "company",
        select: u.id

    # Combine visibility: Companies (all) + Degree 1 + Degree 2 + Self
    # And filter out blocked
    Post
    |> where(
      [p],
      p.author_id in subquery(company_ids_query) or
        p.author_id in subquery(degree_1_query) or
        p.author_id in subquery(degree_2_query) or
        p.author_id == ^user.id
    )
    |> where([p], p.author_id not in subquery(blocked_ids_query))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:author, :hashtags, :interactions, :original_post])
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
      join: ph in PostHashtag,
      on: ph.hashtag_id == h.id,
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

      {company,
       %{likes: likes, dislikes: dislikes, recommendations: recommendations, score: score}}
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

      top_posts =
        Enum.sort_by(posts_with_engagement, fn {_post, eng} -> eng end, :desc) |> Enum.take(5)

      bottom_posts =
        Enum.sort_by(posts_with_engagement, fn {_post, eng} -> eng end, :asc) |> Enum.take(5)

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
    get_influence_network_recursive(
      user.id,
      max_depth,
      1,
      %{0 => [user.id]},
      MapSet.new([user.id])
    )
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

  # --- Additional Functions for Complete Requirement Coverage ---

  @doc """
  Counts the number of followers for a user or company.
  """
  def count_followers(%User{} = user) do
    from(r in Relationship,
      where: r.target_id == ^user.id and r.type == "follow",
      select: count(r.id)
    )
    |> Repo.one() || 0
  end

  @doc """
  Gets all followers of a user or company.
  """
  def get_followers(%User{} = user) do
    from(u in User,
      join: r in Relationship,
      on: r.source_id == u.id,
      where: r.target_id == ^user.id and r.type == "follow"
    )
    |> Repo.all()
  end

  @doc """
  Gets the list of users that the given user is following.
  """
  def get_following(%User{} = user) do
    from(u in User,
      join: r in Relationship,
      on: r.target_id == u.id,
      where: r.source_id == ^user.id and r.type == "follow"
    )
    |> Repo.all()
  end

  @doc """
  Counts the number of likes for a specific post.
  """
  def count_likes(%Post{} = post) do
    from(i in Interaction,
      where: i.post_id == ^post.id and i.type == "like",
      select: count(i.id)
    )
    |> Repo.one() || 0
  end

  @doc """
  Counts the number of dislikes for a specific post.
  """
  def count_dislikes(%Post{} = post) do
    from(i in Interaction,
      where: i.post_id == ^post.id and i.type == "dislike",
      select: count(i.id)
    )
    |> Repo.one() || 0
  end

  @doc """
  Gets engagement stats (likes and dislikes) for a specific post.
  """
  def get_post_engagement(%Post{} = post) do
    %{
      likes: count_likes(post),
      dislikes: count_dislikes(post)
    }
  end

  @doc """
  Gets all followers that have been blocked by a user.
  """
  def get_blocked_followers(%User{} = user) do
    # Get users who follow me AND whom I have blocked
    follower_ids =
      from(r in Relationship,
        where: r.target_id == ^user.id and r.type == "follow",
        select: r.source_id
      )
      |> Repo.all()

    from(u in User,
      join: r in Relationship,
      on: r.target_id == u.id,
      where: r.source_id == ^user.id and r.type == "block" and u.id in ^follower_ids
    )
    |> Repo.all()
  end

  @doc """
  Gets all users or companies that a user has blocked.
  """
  def get_blocked_users(%User{} = user) do
    from(u in User,
      join: r in Relationship,
      on: r.target_id == u.id,
      where: r.source_id == ^user.id and r.type == "block"
    )
    |> Repo.all()
  end

  @doc """
  Gets companies ranked by number of dislikes (most disliked first).
  """
  def get_companies_by_dislikes do
    from(u in User,
      join: p in assoc(u, :posts),
      join: i in assoc(p, :interactions),
      where: u.type == "company" and i.type == "dislike",
      group_by: u.id,
      select: {u, count(i.id)},
      order_by: [desc: count(i.id)],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Gets recommendations received by a company with details of who recommended.
  """
  def get_recommendations_for_company(%User{type: "company"} = company) do
    from(r in Relationship,
      where: r.target_id == ^company.id and r.type == "recommend",
      preload: [:source]
    )
    |> Repo.all()
    |> Enum.map(fn relationship ->
      %{
        recommended_by: relationship.source,
        recommended_at: relationship.inserted_at
      }
    end)
  end

  @doc """
  Checks if a user can see a specific post based on visibility rules.
  """
  def can_see_post?(%User{} = viewer, %Post{} = post) do
    post = Repo.preload(post, :author)

    # Check if viewer is blocked
    is_blocked =
      Repo.exists?(
        from r in Relationship,
          where:
            (r.source_id == ^viewer.id and r.target_id == ^post.author_id and r.type == "block") or
              (r.source_id == ^post.author_id and r.target_id == ^viewer.id and r.type == "block")
      )

    if is_blocked do
      false
    else
      cond do
        # Company posts are visible to everyone
        post.author.type == "company" ->
          true

        # Own posts are visible
        post.author_id == viewer.id ->
          true

        # Check if viewer follows author (degree 1)
        Repo.exists?(
          from r in Relationship,
            where:
              r.source_id == ^viewer.id and r.target_id == ^post.author_id and r.type == "follow"
        ) ->
          true

        # Check if viewer follows someone who follows author (degree 2)
        true ->
          viewer_follows =
            from r in Relationship,
              where: r.source_id == ^viewer.id and r.type == "follow",
              select: r.target_id

          Repo.exists?(
            from r in Relationship,
              where:
                r.source_id in subquery(viewer_follows) and r.target_id == ^post.author_id and
                  r.type == "follow"
          )
      end
    end
  end
end
