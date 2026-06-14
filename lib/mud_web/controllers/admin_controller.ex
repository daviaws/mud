defmodule MudWeb.AdminController do
  use MudWeb, :controller
  alias MudWeb.Plugs.AdminAuth

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def do_login(conn, %{"password" => password}) do
    if AdminAuth.valid_password?(password) do
      conn
      |> put_session(:admin_authenticated, true)
      |> redirect(to: "/admin/blog")
    else
      render(conn, :login, error: "Senha incorreta")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:admin_authenticated)
    |> redirect(to: "/blog")
  end
end
