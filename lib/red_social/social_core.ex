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

  # --- Posts ---

  def create_post(%User{} = author, attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:author, author)
    |> Repo.insert()
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
        where: (r.source_id == ^user.id and r.target_id == r.target_id and r.type == "block") or
               (r.source_id == r.source_id and r.target_id == ^user.id and r.type == "block"),
        select: fragment("CASE WHEN ? = ? THEN ? ELSE ? END", r.source_id, ^user.id, r.target_id, r.source_id)

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
end
