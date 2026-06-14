defmodule MudWeb.BlogLive.Show do
  use MudWeb, :live_view
  alias Mud.Blog

  def mount(%{"board_slug" => slug, "post_id" => post_id}, _session, socket) do
    boards = Blog.visible_boards()
    board = Enum.find(boards, &(&1.slug == slug))

    post = if board, do: Blog.get_post(board.id, String.to_integer(post_id)), else: nil
    sections = if post, do: Blog.list_sections(board.id, post.id), else: []

    {:ok, assign(socket,
      board: board,
      post: post,
      sections: sections,
      expanded: MapSet.new()
    )}
  end

  def handle_event("toggle_section", %{"position" => pos}, socket) do
    pos = String.to_integer(pos)
    expanded =
      if MapSet.member?(socket.assigns.expanded, pos),
        do: MapSet.delete(socket.assigns.expanded, pos),
        else: MapSet.put(socket.assigns.expanded, pos)

    {:noreply, assign(socket, expanded: expanded)}
  end

  def render(assigns) do
    ~H"""
    <div class="blog-show">
      <%= if @post do %>
        <nav class="breadcrumb">
          <a href="/blog">Blog</a> /
          <a href={"/blog/#{@board.slug}"}><%= @board.name %></a>
        </nav>

        <article>
          <h1><%= @post.title %></h1>
          <time><%= Calendar.strftime(@post.inserted_at, "%d/%m/%Y") %></time>
          <a href={"/blog/#{@board.slug}/#{@post.id}/#{@post.slug}/export"}>
            ↓ exportar MD
          </a>
          <div class="post-body" id="post-body" phx-update="ignore">
            <div data-md={@post.body}></div>
          </div>

          <%= if length(@sections) > 0 do %>
            <div class="sections">
              <%= for s <- @sections do %>
                <div class="section">
                  <button
                    class={"section-toggle #{if MapSet.member?(@expanded, s.position), do: "open"}"}
                    phx-click="toggle_section"
                    phx-value-position={s.position}>
                    <%= if MapSet.member?(@expanded, s.position), do: "▾", else: "▸" %>
                    <%= s.title %>
                  </button>
                  <%= if MapSet.member?(@expanded, s.position) do %>
                    <div class="section-body" id={"section-#{s.position}"} phx-update="ignore">
                      <div data-md={s.body}></div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </article>
      <% else %>
        <p>Post não encontrado.</p>
      <% end %>
    </div>
    """
  end
end
