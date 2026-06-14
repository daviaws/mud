defmodule Mud.Blog do
  require Record

  # --- Mnesia ---

  @tables [:blog_board, :blog_post, :blog_section]

  Record.defrecord(:blog_board, [:id, :name, :slug, :visible, :position, :next_post_id])
  Record.defrecord(:blog_post, [:id, :board_id, :slug, :title, :body, :inserted_at])
  Record.defrecord(:blog_section, [:id, :post_id, :title, :body, :position])

  def setup do
    with :ok <- setup_table(:blog_board, [:id, :name, :slug, :visible, :position, :next_post_id], []),
         :ok <- setup_table(:blog_post, [:id, :board_id, :slug, :title, :body, :inserted_at], index: [:board_id]),
         :ok <- setup_table(:blog_section, [:id, :post_id, :title, :body, :position], index: [:post_id]) do
      :ok = :mnesia.wait_for_tables(@tables, 10_000)
    end
  end

  defp setup_table(name, attrs, opts) do
    args = [attributes: attrs, disc_copies: [node()]] ++ opts

    case :mnesia.create_table(name, args) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^name}} -> :ok
      {:aborted, reason} -> raise "Mnesia tabela #{name}: #{inspect(reason)}"
    end
  end

  # --- Boards ---

  def create_board(name) do
    id = uuid()
    slug = slugify(name)

    position =
      :mnesia.dirty_all_keys(:blog_board)
      |> length()

    rec = blog_board(id: id, name: name, slug: slug, visible: false, position: position, next_post_id: 1)
    :mnesia.dirty_write(rec)
    to_board(rec)
  end

  def list_boards do
    :mnesia.dirty_match_object({:blog_board, :_, :_, :_, :_, :_, :_})
    |> Enum.map(&to_board/1)
    |> Enum.sort_by(& &1.position)
  end

  def visible_boards do
    list_boards() |> Enum.filter(& &1.visible)
  end

  def toggle_board_visibility(id) do
    case :mnesia.dirty_read(:blog_board, id) do
      [rec] ->
        updated = blog_board(rec, visible: !blog_board(rec, :visible))
        :mnesia.dirty_write(updated)
        to_board(updated)

      [] ->
        {:error, :not_found}
    end
  end

  def delete_board(id) do
    :mnesia.dirty_delete(:blog_board, id)
  end

  defp to_board(rec) do
    %{
      id: blog_board(rec, :id),
      name: blog_board(rec, :name),
      slug: blog_board(rec, :slug),
      visible: blog_board(rec, :visible),
      position: blog_board(rec, :position),
      next_post_id: blog_board(rec, :next_post_id)
    }
  end

  # --- Posts ---

  def create_post(board_id, title, body) do
    {:atomic, post_map} =
      :mnesia.transaction(fn ->
        [board_rec] = :mnesia.read(:blog_board, board_id)
        post_id = blog_board(board_rec, :next_post_id)

        :mnesia.write(blog_board(board_rec, next_post_id: post_id + 1))

        slug = slugify(title)
        rec = blog_post(id: {board_id, post_id}, board_id: board_id, slug: slug, title: title, body: body, inserted_at: now())
        :mnesia.write(rec)
        to_post(rec)
      end)

    post_map
  end

  def update_post(board_id, post_id, attrs) do
    case :mnesia.dirty_read(:blog_post, {board_id, post_id}) do
      [rec] ->
        updated =
          blog_post(rec,
            title: Map.get(attrs, :title, blog_post(rec, :title)),
            body: Map.get(attrs, :body, blog_post(rec, :body)),
            slug: Map.get(attrs, :slug, blog_post(rec, :slug))
          )

        :mnesia.dirty_write(updated)
        to_post(updated)

      [] ->
        {:error, :not_found}
    end
  end

  def get_post(board_id, post_id) do
    case :mnesia.dirty_read(:blog_post, {board_id, post_id}) do
      [rec] -> to_post(rec)
      [] -> nil
    end
  end

  def get_post_by_slug(board_id, slug) do
    :mnesia.dirty_index_read(:blog_post, board_id, :board_id)
    |> Enum.find(&(blog_post(&1, :slug) == slug))
    |> case do
      nil -> nil
      rec -> to_post(rec)
    end
  end

  def list_posts(board_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    page = Keyword.get(opts, :page, 1)
    offset = (page - 1) * limit

    all =
      :mnesia.dirty_index_read(:blog_post, board_id, :board_id)
      |> Enum.map(&to_post/1)
      |> Enum.sort_by(& &1.id, :desc)

    total = length(all)
    total_pages = ceil(total / limit)

    entries = all |> Enum.drop(offset) |> Enum.take(limit)

    %{
      entries: entries,
      page: page,
      total_pages: total_pages,
      total: total
    }
  end

  def delete_post(board_id, post_id) do
    delete_sections_by_post({board_id, post_id})
    :mnesia.dirty_delete(:blog_post, {board_id, post_id})
  end

  defp to_post(rec) do
    {board_id, post_id} = blog_post(rec, :id)

    %{
      id: post_id,
      board_id: board_id,
      slug: blog_post(rec, :slug),
      title: blog_post(rec, :title),
      body: blog_post(rec, :body),
      inserted_at: blog_post(rec, :inserted_at)
    }
  end

  # --- Sections ---

  def put_sections(board_id, post_id, sections) do
    composite_id = {board_id, post_id}

    :mnesia.transaction(fn ->
      :mnesia.index_read(:blog_section, composite_id, :post_id)
      |> Enum.each(&:mnesia.delete_object/1)

      sections
      |> Enum.with_index()
      |> Enum.each(fn {s, idx} ->
        rec =
          blog_section(
            id: {composite_id, idx},
            post_id: composite_id,
            title: s.title,
            body: s.body,
            position: idx
          )

        :mnesia.write(rec)
      end)
    end)

    :ok
  end

  def list_sections(board_id, post_id) do
    :mnesia.dirty_index_read(:blog_section, {board_id, post_id}, :post_id)
    |> Enum.map(&to_section/1)
    |> Enum.sort_by(& &1.position)
  end

  defp delete_sections_by_post(composite_id) do
    :mnesia.dirty_index_read(:blog_section, composite_id, :post_id)
    |> Enum.each(&:mnesia.dirty_delete_object/1)
  end

  defp to_section(rec) do
    {_composite_id, position} = blog_section(rec, :id)

    %{
      id: position,
      post_id: blog_section(rec, :post_id),
      title: blog_section(rec, :title),
      body: blog_section(rec, :body),
      position: blog_section(rec, :position)
    }
  end

  # --- Helpers ---

  defp uuid, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.trim("-")
  end

  defp now, do: DateTime.utc_now()
end
