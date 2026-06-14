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

  pipeline :admin_auth do
    plug MudWeb.Plugs.AdminAuth
  end

  scope "/blog", MudWeb do
    pipe_through :browser

    live "/", BlogLive.Index, :index
    live "/:board_slug", BlogLive.Index, :board
    live "/:board_slug/:post_id/:slug", BlogLive.Show, :show
    get "/:board_slug/:post_id/:slug/export", BlogController, :export
  end

  scope "/admin", MudWeb do
    pipe_through :browser

    get "/login", AdminController, :login
    post "/login", AdminController, :do_login
    delete "/logout", AdminController, :logout
  end


  scope "/admin", MudWeb do
    pipe_through [:browser, :admin_auth]

    live "/blog", AdminLive.Blog.Index, :index
    live "/blog/new", AdminLive.Blog.Post, :new
    live "/blog/:board_slug/:post_id", AdminLive.Blog.Post, :edit
  end

  scope "/" do
    pipe_through(:browser)
    observer_dashboard("/observer")
  end
end
