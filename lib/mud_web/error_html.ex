defmodule MudWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", _assigns), do: "Not found"
  def render("500.html", _assigns), do: "Internal server error"
end
