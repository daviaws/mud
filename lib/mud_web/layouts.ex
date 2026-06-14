defmodule MudWeb.Layouts do
  use Phoenix.Component
  import Phoenix.Controller, only: [get_csrf_token: 0]

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Mud</title>
        <script src="/assets/app.js"></script>
        <link rel="stylesheet" href="/assets/app.css" />
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    <div class="page">
      <%= @inner_content %>
    </div>
    """
  end
end
