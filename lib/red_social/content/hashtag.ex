defmodule RedSocial.Content.Hashtag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hashtags" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(hashtag, attrs) do
    hashtag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
