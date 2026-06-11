defmodule MudWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import Observer.Web.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {MudWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)
    observer_dashboard("/observer")
  end
end
