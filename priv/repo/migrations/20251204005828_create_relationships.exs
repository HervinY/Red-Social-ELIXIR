defmodule RedSocial.Repo.Migrations.CreateRelationships do
  use Ecto.Migration

  def change do
    create table(:relationships) do
      add :type, :string
      add :source_id, references(:users, on_delete: :nothing)
      add :target_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:relationships, [:source_id])
    create index(:relationships, [:target_id])
  end
end
