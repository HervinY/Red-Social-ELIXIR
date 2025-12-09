defmodule RedSocial.Content.PostHashtag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_hashtags" do
    field :post_id, :id
    field :hashtag_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post_hashtag, attrs) do
    post_hashtag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
