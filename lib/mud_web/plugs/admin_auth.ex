defmodule MudWeb.Plugs.AdminAuth do
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @password "1234"

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_authenticated) do
      conn
    else
      conn
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end

  def valid_password?(@password), do: true
  def valid_password?(_), do: false
end
