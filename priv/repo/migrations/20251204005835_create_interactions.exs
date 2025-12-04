defmodule RedSocial.Repo.Migrations.CreateInteractions do
  use Ecto.Migration

  def change do
    create table(:interactions) do
      add :type, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :post_id, references(:posts, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:interactions, [:user_id])
    create index(:interactions, [:post_id])
  end
end
