defmodule RedSocial.Repo.Migrations.AddOriginalPostToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :original_post_id, references(:posts, on_delete: :nilify_all)
    end

    create index(:posts, [:original_post_id])
  end
end
