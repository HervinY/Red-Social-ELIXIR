# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
alias RedSocial.Repo
alias RedSocial.Accounts.User
alias RedSocial.Social.Relationship
alias RedSocial.Content.{Post, Interaction, Hashtag, PostHashtag}
alias RedSocial.SocialCore

# Helper to create user
create_user = fn attrs ->
  case SocialCore.create_user(attrs) do
    {:ok, user} -> user
    {:error, _} -> Repo.get_by(User, username: attrs.username)
  end
end

# 1. Create Companies
companies = [
  %{name: "TechCorp", username: "techcorp", email: "contact@techcorp.com", type: "company", bio: "Leading tech solutions"},
  %{name: "Foodies", username: "foodies", email: "yum@foodies.com", type: "company", bio: "Best food in town"},
  %{name: "TravelInc", username: "travelinc", email: "go@travelinc.com", type: "company", bio: "Explore the world"}
]

company_structs = Enum.map(companies, create_user)

# 2. Create Users
users = Enum.map(1..10, fn i ->
  %{
    name: "User #{i}",
    username: "user#{i}",
    email: "user#{i}@example.com",
    type: "person",
    bio: "Just a normal user #{i}"
  }
end)

user_structs = Enum.map(users, create_user)

# 3. Create Relationships

# Friendships / Follows
# User 1 follows User 2, 3, 4
SocialCore.follow(Enum.at(user_structs, 0), Enum.at(user_structs, 1))
SocialCore.follow(Enum.at(user_structs, 0), Enum.at(user_structs, 2))
SocialCore.follow(Enum.at(user_structs, 0), Enum.at(user_structs, 3))

# User 2 follows User 5 (So User 1 should see User 5's posts via Degree 2)
SocialCore.follow(Enum.at(user_structs, 1), Enum.at(user_structs, 4))

# User 3 follows User 6
SocialCore.follow(Enum.at(user_structs, 2), Enum.at(user_structs, 5))

# User 1 follows TechCorp
SocialCore.follow(Enum.at(user_structs, 0), Enum.at(company_structs, 0))

# Blocks
# User 1 blocks User 6 (So User 1 should NOT see User 6's posts even though User 3 follows them)
SocialCore.block(Enum.at(user_structs, 0), Enum.at(user_structs, 5))

# Recommendations
# TechCorp recommends Foodies
SocialCore.recommend(Enum.at(company_structs, 0), Enum.at(company_structs, 1))

# 4. Create Hashtags
hashtags = ["elixir", "phoenix", "tech", "food", "travel", "coding"]
hashtag_structs = Enum.map(hashtags, fn name ->
  {:ok, tag} = Repo.insert(%Hashtag{name: name}, on_conflict: :nothing)
  tag
end)

# 5. Create Posts
create_post_with_hashtags = fn user, content, tags ->
  {:ok, post} = SocialCore.create_post(user, %{content: content})
  # Add hashtags manually since SocialCore.create_post might not handle them yet in the simple version
  # We'll just insert PostHashtag directly for seeds
  Enum.each(tags, fn tag_name ->
    tag = Repo.get_by(Hashtag, name: tag_name)
    Repo.insert(%PostHashtag{post_id: post.id, hashtag_id: tag.id})
  end)
  post
end

# User 2 posts (Visible to User 1)
create_post_with_hashtags.(Enum.at(user_structs, 1), "Hello world from User 2!", ["elixir"])
create_post_with_hashtags.(Enum.at(user_structs, 1), "Learning Phoenix is fun.", ["phoenix", "coding"])

# User 5 posts (Visible to User 1 via User 2)
create_post_with_hashtags.(Enum.at(user_structs, 4), "I am User 5, friend of User 2.", ["tech"])

# User 6 posts (Blocked by User 1, should NOT be visible)
create_post_with_hashtags.(Enum.at(user_structs, 5), "I am User 6, you shouldn't see this User 1!", ["spam"])

# TechCorp posts
create_post_with_hashtags.(Enum.at(company_structs, 0), "New product launch!", ["tech", "innovation"])

# 6. Interactions
# User 1 likes TechCorp's post
tech_post = Repo.one(from p in Post, where: p.author_id == ^Enum.at(company_structs, 0).id, limit: 1)
SocialCore.like(Enum.at(user_structs, 0), tech_post)

# User 2 likes TechCorp's post
SocialCore.like(Enum.at(user_structs, 1), tech_post)

# User 3 likes Foodies (we need a post for Foodies)
food_post = create_post_with_hashtags.(Enum.at(company_structs, 1), "Yummy burger!", ["food"])
SocialCore.like(Enum.at(user_structs, 2), food_post)

IO.puts "Seeds executed successfully!"
