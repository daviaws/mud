defmodule MudWeb.BlogController do
  use MudWeb, :controller
  alias Mud.Blog

  def export(conn, %{"board_slug" => board_slug, "post_id" => post_id, "slug" => slug}) do
    board = Enum.find(Blog.visible_boards(), &(&1.slug == board_slug))

    if board do
      post = Blog.get_post(board.id, String.to_integer(post_id))
      sections = Blog.list_sections(board.id, post.id)
      md = render_md(post, sections)

      conn
      |> put_resp_content_type("text/markdown")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{slug}.md"))
      |> send_resp(200, md)
    else
      send_resp(conn, 404, "Not found")
    end
  end

  defp render_md(post, sections) do
    sections_md =
      Enum.map_join(sections, "\n\n", fn s ->
        "## #{s.title}\n\n#{s.body}"
      end)

    "# #{post.title}\n\n#{post.body}\n\n#{sections_md}"
    |> String.trim()
  end
end
