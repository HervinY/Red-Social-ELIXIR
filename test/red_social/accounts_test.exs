defmodule RedSocial.AccountsTest do
  use RedSocial.DataCase

  alias RedSocial.Accounts

  describe "users" do
    alias RedSocial.Accounts.User

    import RedSocial.AccountsFixtures

    @invalid_attrs %{name: nil, type: nil, username: nil, email: nil, bio: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        name: "some name",
        type: "some type",
        username: "some username",
        email: "some email",
        bio: "some bio"
      }

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.name == "some name"
      assert user.type == "some type"
      assert user.username == "some username"
      assert user.email == "some email"
      assert user.bio == "some bio"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        name: "some updated name",
        type: "some updated type",
        username: "some updated username",
        email: "some updated email",
        bio: "some updated bio"
      }

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.name == "some updated name"
      assert user.type == "some updated type"
      assert user.username == "some updated username"
      assert user.email == "some updated email"
      assert user.bio == "some updated bio"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
