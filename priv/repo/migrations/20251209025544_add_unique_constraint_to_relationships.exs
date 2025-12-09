defmodule RedSocial.Repo.Migrations.AddUniqueConstraintToRelationships do
  use Ecto.Migration

  def up do
    # Delete duplicate relationships before creating unique index
    execute """
    DELETE FROM relationships
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM relationships
      GROUP BY source_id, target_id, type
    )
    """

    # Create unique index
    create unique_index(:relationships, [:source_id, :target_id, :type],
             name: :relationships_source_target_type_index
           )
  end

  def down do
    drop index(:relationships, [:source_id, :target_id, :type],
           name: :relationships_source_target_type_index
         )
  end
end
