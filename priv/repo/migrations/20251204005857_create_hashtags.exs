defmodule RedSocial.Repo.Migrations.CreateHashtags do
  use Ecto.Migration

  def change do
    create table(:hashtags) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:hashtags, [:name])
  end
end
