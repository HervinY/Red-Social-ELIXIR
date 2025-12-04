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
# Foodies recommends TravelInc
SocialCore.recommend(Enum.at(company_structs, 1), Enum.at(company_structs, 2))

# Employment relationships (person works at company)
SocialCore.employ(Enum.at(company_structs, 0), Enum.at(user_structs, 0))
SocialCore.employ(Enum.at(company_structs, 0), Enum.at(user_structs, 1))
SocialCore.employ(Enum.at(company_structs, 1), Enum.at(user_structs, 2))

# Customer relationships (person is customer of company)
SocialCore.add_customer(Enum.at(company_structs, 0), Enum.at(user_structs, 3))
SocialCore.add_customer(Enum.at(company_structs, 0), Enum.at(user_structs, 4))
SocialCore.add_customer(Enum.at(company_structs, 1), Enum.at(user_structs, 5))
SocialCore.add_customer(Enum.at(company_structs, 1), Enum.at(user_structs, 6))
SocialCore.add_customer(Enum.at(company_structs, 2), Enum.at(user_structs, 7))

# Create mutual friendships (User 1 and User 2 are friends)
SocialCore.follow(Enum.at(user_structs, 1), Enum.at(user_structs, 0))  # User 2 follows back User 1

# 4. Create Posts with automatic hashtag extraction
# User 2 posts (Visible to User 1)
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 1), %{content: "Hello world from User 2! #elixir #programming"})
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 1), %{content: "Learning Phoenix is fun. #phoenix #coding #elixir"})

# User 5 posts (Visible to User 1 via User 2 - Degree 2)
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 4), %{content: "I am User 5, friend of User 2. #tech #networking"})

# User 6 posts (Blocked by User 1, should NOT be visible)
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 5), %{content: "I am User 6, you shouldn't see this User 1! #spam"})

# User 3 posts
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 2), %{content: "Working on exciting stuff! #tech #innovation"})

# User 4 posts
{:ok, _} = SocialCore.create_post(Enum.at(user_structs, 3), %{content: "Love functional programming! #elixir #fp"})

# TechCorp posts
{:ok, tech_post} = SocialCore.create_post(Enum.at(company_structs, 0), %{content: "New product launch! #tech #innovation #startup"})
{:ok, _} = SocialCore.create_post(Enum.at(company_structs, 0), %{content: "We're hiring Elixir developers! #elixir #jobs #tech"})

# Foodies posts
{:ok, food_post} = SocialCore.create_post(Enum.at(company_structs, 1), %{content: "Yummy burger special today! #food #burgers #delicious"})
{:ok, food_post2} = SocialCore.create_post(Enum.at(company_structs, 1), %{content: "New vegan menu! #food #vegan #healthy"})

# TravelInc posts
{:ok, travel_post} = SocialCore.create_post(Enum.at(company_structs, 2), %{content: "Amazing destinations await! #travel #adventure #vacation"})

# 5. Interactions - Create diverse engagement
# Multiple users like TechCorp posts
SocialCore.like(Enum.at(user_structs, 0), tech_post)
SocialCore.like(Enum.at(user_structs, 1), tech_post)
SocialCore.like(Enum.at(user_structs, 2), tech_post)
SocialCore.like(Enum.at(user_structs, 3), tech_post)

# Users like Foodies posts
SocialCore.like(Enum.at(user_structs, 2), food_post)
SocialCore.like(Enum.at(user_structs, 4), food_post)
SocialCore.like(Enum.at(user_structs, 5), food_post)
SocialCore.like(Enum.at(user_structs, 6), food_post2)
SocialCore.like(Enum.at(user_structs, 7), food_post2)

# Some dislikes for variety
SocialCore.dislike(Enum.at(user_structs, 8), food_post2)

# Users like TravelInc posts
SocialCore.like(Enum.at(user_structs, 7), travel_post)
SocialCore.like(Enum.at(user_structs, 8), travel_post)

# Reposts
SocialCore.repost(Enum.at(user_structs, 0), tech_post)
SocialCore.repost(Enum.at(user_structs, 1), food_post)

IO.puts "Seeds executed successfully!"
IO.puts "- Created 10 users and 3 companies"
IO.puts "- Established follow, block, employment, and customer relationships"
IO.puts "- Generated posts with automatic hashtag extraction"
IO.puts "- Added diverse interactions (likes, dislikes, reposts)"
