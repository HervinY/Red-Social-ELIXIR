defmodule RedSocial.Content.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "interactions" do
    field :type, :string
    belongs_to :user, RedSocial.Accounts.User
    belongs_to :post, RedSocial.Content.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:type])
    |> validate_required([:type])
    |> validate_inclusion(:type, ["like", "dislike", "repost"])
    |> unique_constraint([:user_id, :post_id, :type], 
         name: :interactions_user_post_type_index,
         message: "You have already performed this action on this post")
  end
end
