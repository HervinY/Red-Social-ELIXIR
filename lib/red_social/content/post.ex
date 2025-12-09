defmodule RedSocial.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    belongs_to :author, RedSocial.Accounts.User
    belongs_to :original_post, RedSocial.Content.Post
    has_many :interactions, RedSocial.Content.Interaction
    has_many :reposts, RedSocial.Content.Post, foreign_key: :original_post_id
    many_to_many :hashtags, RedSocial.Content.Hashtag, join_through: RedSocial.Content.PostHashtag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :original_post_id])
    |> validate_required([:content])
  end
end
