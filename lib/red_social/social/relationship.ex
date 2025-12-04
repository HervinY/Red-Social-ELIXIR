defmodule RedSocial.Social.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "relationships" do
    field :type, :string
    belongs_to :source, RedSocial.Accounts.User
    belongs_to :target, RedSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
