defmodule MudWeb.AdminLive.Blog.Post do
  use MudWeb, :live_view
  alias Mud.Blog

  def mount(params, _session, socket) do
    boards = Blog.list_boards()
    board_id = Map.get(params, "board_id")
    board = Enum.find(boards, &(&1.id == board_id))

    {:ok,
     assign(socket,
       boards: boards,
       board: board,
       post: nil,
       sections: [],
       title: "",
       body: ""
     )}
  end

  def handle_params(%{"board_slug" => slug, "post_id" => post_id}, _uri, socket) do
    board = Enum.find(socket.assigns.boards, &(&1.slug == slug))
    post = Blog.get_post(board.id, String.to_integer(post_id))
    sections = Blog.list_sections(board.id, post.id)

    {:noreply,
     assign(socket,
       board: board,
       post: post,
       sections: sections,
       title: post.title,
       body: post.body
     )}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, post: nil, sections: [], title: "", body: "")}
  end

  # --- Eventos ---

  def handle_event("set_board", %{"board_id" => id}, socket) do
    board = Enum.find(socket.assigns.boards, &(&1.id == id))
    {:noreply, assign(socket, board: board)}
  end

  def handle_event("update_field", %{"field" => "title", "value" => v}, socket),
    do: {:noreply, assign(socket, title: v)}

  def handle_event("update_field", %{"field" => "body", "value" => v}, socket),
    do: {:noreply, assign(socket, body: v)}

  def handle_event("update_field", %{"field" => "section-body-" <> pos, "value" => v}, socket) do
    pos = String.to_integer(pos)

    sections =
      Enum.map(socket.assigns.sections, fn
        s when s.position == pos -> %{s | body: v}
        s -> s
      end)

    {:noreply, assign(socket, sections: sections)}
  end

  def handle_event("add_section", _, socket) do
    sections =
      socket.assigns.sections ++
        [%{id: nil, title: "", body: "", position: length(socket.assigns.sections)}]

    {:noreply, assign(socket, sections: sections)}
  end

  def handle_event("remove_section", %{"position" => pos}, socket) do
    pos = String.to_integer(pos)
    sections = socket.assigns.sections |> Enum.reject(&(&1.position == pos)) |> reindex()
    {:noreply, assign(socket, sections: sections)}
  end

  def handle_event("update_section", %{"position" => pos, "field" => "title", "value" => v}, socket) do
    pos = String.to_integer(pos)

    sections =
      Enum.map(socket.assigns.sections, fn
        s when s.position == pos -> %{s | title: v}
        s -> s
      end)

    {:noreply, assign(socket, sections: sections)}
  end

  def handle_event("save", _, socket) do
    %{board: board, post: post, title: title, body: body, sections: sections} = socket.assigns

    if post do
      Blog.update_post(board.id, post.id, %{title: title, body: body})
      Blog.put_sections(board.id, post.id, sections)
    else
      new_post = Blog.create_post(board.id, title, body)
      Blog.put_sections(board.id, new_post.id, sections)
    end

    {:noreply, push_navigate(socket, to: "/admin/blog?board_slug=#{board.slug}")}
  end

  defp reindex(sections) do
    sections |> Enum.with_index() |> Enum.map(fn {s, i} -> %{s | position: i} end)
  end

  defp md_editor(assigns) do
    ~H"""
    <div id={"editor-#{@field}"}
         class="md-editor"
         phx-hook="MarkdownEditor"
         phx-update="ignore"
         data-field={@field}>
      <div class="md-toolbar">
        <button data-action="bold"><b>B</b></button>
        <button data-action="italic"><i>I</i></button>
        <button data-action="heading2">H2</button>
        <button data-action="heading3">H3</button>
        <button data-action="link">🔗</button>
        <button data-action="code">` `</button>
        <button data-action="codeblock">```</button>
        <button data-action="ul">• lista</button>
        <button data-action="fullscreen">⛶</button>
      </div>
      <div class="cm-container"></div>
      <textarea name={@field} style="display:none"><%= @value %></textarea>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="post-form">
      <h1><%= if @post, do: "Editar post", else: "Novo post" %></h1>

      <div>
        <label>Board</label>
        <select phx-change="set_board" name="board_id">
          <option value="">-- seleciona --</option>
          <%= for b <- @boards do %>
            <option value={b.id} selected={@board && @board.id == b.id}><%= b.name %></option>
          <% end %>
        </select>
      </div>

      <div>
        <label># Título</label>
        <input
          type="text"
          value={@title}
          phx-keyup="update_field"
          phx-value-field="title"
        />
      </div>

      <div>
        <label>Corpo (MD)</label>
        <.md_editor field="body" value={@body} />
      </div>

      <h2>Sections</h2>

      <%= for s <- @sections do %>
        <div class="section-editor">
          <input
            type="text"
            value={s.title}
            placeholder="## Título da section"
            phx-blur="update_section"
            phx-value-position={s.position}
            phx-value-field="title"
          />
          <.md_editor field={"section-body-#{s.position}"} value={s.body} />
          <button phx-click="remove_section" phx-value-position={s.position}>
            Remover section
          </button>
        </div>
      <% end %>

      <button phx-click="add_section">+ Section</button>
      <button phx-click="save">Salvar</button>

      <h2>Preview</h2>
      <div id="preview" phx-update="ignore">
        <div id="preview-content"></div>
      </div>

      <script>
        function renderPreview() {
          const title = document.querySelector("input[phx-value-field='title']")?.value || "";
          const body = document.querySelector("textarea[name='body']")?.value || "";

          const sections = [...document.querySelectorAll(".section-editor")].map((el, i) => ({
            title: el.querySelector("input")?.value || "",
            body: el.querySelector(`textarea[name='section-body-${i}']`)?.value || ""
          }));

          let md = `# ${title}\n\n${body}`;
          sections.forEach(s => { md += `\n\n## ${s.title}\n\n${s.body}`; });

          document.getElementById("preview-content").innerHTML = marked.parse(md);
        }

        window.addEventListener("md-update", renderPreview);
        document.addEventListener("phx:update", renderPreview);
        document.addEventListener("input", renderPreview);
      </script>
    </div>
    """
  end
end
