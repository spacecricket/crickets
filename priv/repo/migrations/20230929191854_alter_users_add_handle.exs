defmodule Crickets.Repo.Migrations.AlterUsersAddHandle do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :handle, :citext
    end

    create unique_index(:users, [:handle])
  end
end
