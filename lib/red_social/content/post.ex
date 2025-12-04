defmodule RedSocial.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    belongs_to :author, RedSocial.Accounts.User
    has_many :interactions, RedSocial.Content.Interaction
    many_to_many :hashtags, RedSocial.Content.Hashtag, join_through: RedSocial.Content.PostHashtag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end
end
