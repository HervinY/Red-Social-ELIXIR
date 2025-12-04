defmodule RedSocial.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :name, :string
    field :type, :string
    field :bio, :string

    has_many :posts, RedSocial.Content.Post, foreign_key: :author_id
    has_many :interactions, RedSocial.Content.Interaction
    has_many :active_relationships, RedSocial.Social.Relationship, foreign_key: :source_id
    has_many :passive_relationships, RedSocial.Social.Relationship, foreign_key: :target_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :name, :type, :bio])
    |> validate_required([:username, :email, :name, :type, :bio])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
end
