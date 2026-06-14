defmodule MudWeb.BlogLive.Index do
  use MudWeb, :live_view
  alias Mud.Blog

  def mount(_params, _session, socket) do
    boards = Blog.visible_boards()
    {:ok, assign(socket, boards: boards, selected_board: nil, posts: %{entries: [], page: 1, total_pages: 1})}
  end

  def handle_params(%{"board_slug" => slug} = params, _uri, socket) do
    board = Enum.find(socket.assigns.boards, &(&1.slug == slug))
    page = Map.get(params, "page", "1") |> String.to_integer()
    posts = if board, do: Blog.list_posts(board.id, page: page), else: %{entries: [], page: 1, total_pages: 1}
    {:noreply, assign(socket, selected_board: board, posts: posts)}
  end

  def handle_params(_params, _uri, socket) do
    case socket.assigns.boards do
      [first | _] ->
        {:noreply, push_patch(socket, to: "/blog/#{first.slug}")}
      [] ->
        {:noreply, assign(socket, selected_board: nil, posts: %{entries: [], page: 1, total_pages: 1})}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="blog-index">
      <h1>Blog</h1>

      <nav class="board-tabs">
        <%= for b <- @boards do %>
          <a href={"/blog/#{b.slug}"}
             class={"tab #{if @selected_board && @selected_board.id == b.id, do: "active"}"}
          ><%= b.name %></a>
        <% end %>
      </nav>

      <%= if @selected_board do %>
        <div class="post-list">
          <%= for p <- @posts.entries do %>
            <div class="post-card">
              <h2>
                <a href={"/blog/#{@selected_board.slug}/#{p.id}/#{p.slug}"}><%= p.title %></a>
              </h2>
              <time><%= Calendar.strftime(p.inserted_at, "%d/%m/%Y") %></time>
            </div>
          <% end %>

          <%= if @posts.total_pages > 1 do %>
            <nav class="pagination">
              <%= if @posts.page > 1 do %>
                <a href={"/blog/#{@selected_board.slug}?page=#{@posts.page - 1}"}>← anterior</a>
              <% end %>
              <span><%= @posts.page %>/<%= @posts.total_pages %></span>
              <%= if @posts.page < @posts.total_pages do %>
                <a href={"/blog/#{@selected_board.slug}?page=#{@posts.page + 1}"}>próxima →</a>
              <% end %>
            </nav>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
