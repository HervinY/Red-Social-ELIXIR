defmodule RedSocial.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RedSocial.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        bio: "some bio",
        email: "some email",
        name: "some name",
        type: "some type",
        username: "some username"
      })
      |> RedSocial.Accounts.create_user()

    user
  end
end
