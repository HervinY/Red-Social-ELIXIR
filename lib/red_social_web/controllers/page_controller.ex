defmodule RedSocialWeb.PageController do
  use RedSocialWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
