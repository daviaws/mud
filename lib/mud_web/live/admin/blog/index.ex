defmodule MudWeb.AdminLive.Blog.Index do
  use MudWeb, :live_view
  alias Mud.Blog

  def mount(_params, _session, socket) do
    boards = Blog.list_boards()
    {:ok, assign(socket, boards: boards, selected_board: nil, posts: [], new_board_name: "")}
  end

  def handle_params(%{"board_slug" => slug}, _uri, socket) do
    board = Enum.find(socket.assigns.boards, &(&1.slug == slug))
    posts = if board, do: Blog.list_posts(board.id), else: %{entries: []}
    {:noreply, assign(socket, selected_board: board, posts: posts.entries)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # --- Boards ---

  def handle_event("create_board", %{"name" => name}, socket) do
    Blog.create_board(name)
    boards = Blog.list_boards()
    {:noreply, assign(socket, boards: boards, new_board_name: "")}
  end

  def handle_event("toggle_visibility", %{"id" => id}, socket) do
    Blog.toggle_board_visibility(id)
    boards = Blog.list_boards()
    {:noreply, assign(socket, boards: boards)}
  end

  def handle_event("delete_board", %{"id" => id}, socket) do
    Blog.delete_board(id)
    boards = Blog.list_boards()
    {:noreply, assign(socket, boards: boards, selected_board: nil, posts: [])}
  end

  # --- Posts ---

  def handle_event("delete_post", %{"board-id" => board_id, "post-id" => post_id}, socket) do
    Blog.delete_post(board_id, String.to_integer(post_id))
    posts = Blog.list_posts(board_id)
    {:noreply, assign(socket, posts: posts.entries)}
  end

  def render(assigns) do
    ~H"""
    <div class="admin">
      <h1>Admin Blog</h1>

      <section class="boards">
        <h2>Boards</h2>

        <form phx-submit="create_board">
          <input name="name" placeholder="Nome da board" required />
          <button type="submit">Criar</button>
        </form>

        <table>
          <thead>
            <tr>
              <th>Nome</th>
              <th>Slug</th>
              <th>Visível</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for b <- @boards do %>
              <tr>
                <td>
                  <a href={"/admin/blog?board_slug=#{b.slug}"}><%= b.name %></a>
                </td>
                <td><%= b.slug %></td>
                <td>
                  <button phx-click="toggle_visibility" phx-value-id={b.id}>
                    <%= if b.visible, do: "👁 visível", else: "🙈 oculta" %>
                  </button>
                </td>
                <td>
                  <button phx-click="delete_board" phx-value-id={b.id}
                    data-confirm="Deletar board e todos os posts?">
                    ✕
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </section>

      <%= if @selected_board do %>
        <section class="posts">
          <h2>Posts — <%= @selected_board.name %></h2>

          <a href={"/admin/blog/new?board_id=#{@selected_board.id}"}>+ Novo post</a>

          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Título</th>
                <th>Criado em</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @posts do %>
                <tr>
                  <td><%= p.id %></td>
                  <td>
                    <a href={"/admin/blog/#{@selected_board.slug}/#{p.id}"}><%= p.title %></a>
                  </td>
                  <td><%= Calendar.strftime(p.inserted_at, "%d/%m/%Y") %></td>
                  <td>
                    <a href={"/blog/#{@selected_board.slug}/#{p.id}/#{p.slug}"}>↗</a>
                  </td>
                  <td>
                    <button phx-click="delete_post"
                      phx-value-board-id={@selected_board.id}
                      phx-value-post-id={p.id}
                      data-confirm="Deletar post?">
                      ✕
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </section>
      <% end %>
    </div>
    """
  end
end
