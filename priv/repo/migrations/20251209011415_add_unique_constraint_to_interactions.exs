defmodule RedSocial.Repo.Migrations.AddUniqueConstraintToInteractions do
  use Ecto.Migration

  def up do
    # Primero, eliminar interacciones duplicadas, manteniendo solo la más antigua
    execute """
    DELETE FROM interactions
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM interactions
      GROUP BY user_id, post_id, type
    )
    """

    # Ahora crear el índice único
    create unique_index(:interactions, [:user_id, :post_id, :type], 
      name: :interactions_user_post_type_index)
  end

  def down do
    drop index(:interactions, [:user_id, :post_id, :type], 
      name: :interactions_user_post_type_index)
  end
end
