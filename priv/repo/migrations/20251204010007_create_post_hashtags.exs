defmodule RedSocial.Repo.Migrations.CreatePostHashtags do
  use Ecto.Migration

  def change do
    create table(:post_hashtags) do
      add :post_id, references(:posts, on_delete: :nothing)
      add :hashtag_id, references(:hashtags, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:post_hashtags, [:post_id])
    create index(:post_hashtags, [:hashtag_id])
  end
end
