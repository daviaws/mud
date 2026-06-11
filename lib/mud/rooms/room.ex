defmodule Mud.Rooms.Room do
  @moduledoc """
  Uma sala. Mantém os ocupantes como `%{pid => nome}`, onde `pid` é o
  processo da conexão do jogador. Broadcast é simplesmente mandar
  `{:tell, mensagem}` para cada pid presente.

  A sala não conhece `Mud.Characters` — persistência de sala é
  responsabilidade de quem chama (comandos e `Mud.Server`).
  """
  use GenServer

  defstruct [:id, :name, :description, :exits, occupants: %{}]

  ## API

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via(attrs.id))
  end

  @doc "Entra na sala. Retorna a descrição já formatada para o jogador."
  def enter(id, name), do: GenServer.call(via(id), {:enter, name, self()})

  @doc "Sai da sala (assíncrono)."
  def leave(id), do: GenServer.cast(via(id), {:leave, self()})

  @doc "Reolha a sala atual."
  def look(id), do: GenServer.call(via(id), {:look, self()})

  @doc "Fala em voz alta na sala."
  def say(id, name, text), do: GenServer.cast(via(id), {:say, name, text, self()})

  @doc "Resolve uma direção para o id da sala de destino."
  def exit_to(id, dir), do: GenServer.call(via(id), {:exit, dir})

  defp via(id), do: {:via, Registry, {Mud.RoomRegistry, id}}

  ## Callbacks

  @impl true
  def init(attrs) do
    occupants =
      attrs.id
      |> Mud.Characters.by_room()
      |> Enum.flat_map(fn char ->
        case Mud.Sessions.get(char.name) do
          {:ok, pid} ->
            Process.monitor(pid)
            [{pid, char.name}]

          :error ->
            []
        end
      end)
      |> Map.new()

    {:ok, struct(__MODULE__, Map.put(attrs, :occupants, occupants))}
  end

  @impl true
  def handle_call({:enter, name, pid}, _from, state) do
    Process.monitor(pid)
    broadcast(state, "#{name} chega.", except: pid)
    state = put_in(state.occupants[pid], name)
    {:reply, describe(state, pid), state}
  end

  def handle_call({:look, pid}, _from, state) do
    {:reply, describe(state, pid), state}
  end

  def handle_call({:exit, dir}, _from, state) do
    {:reply, Map.fetch(state.exits, dir), state}
  end

  @impl true
  def handle_cast({:leave, pid}, state) do
    {name, occupants} = Map.pop(state.occupants, pid)
    state = %{state | occupants: occupants}
    if name, do: broadcast(state, "#{name} parte.")
    {:noreply, state}
  end

  def handle_cast({:say, name, text, pid}, state) do
    broadcast(state, "#{name} diz: #{text}", except: pid)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {name, occupants} = Map.pop(state.occupants, pid)
    state = %{state | occupants: occupants}
    if name, do: broadcast(state, "#{name} desaparece como fumaça.")
    {:noreply, state}
  end

  ## Helpers

  defp describe(state, pid) do
     plants =
       Mud.Characters.by_room(state.id)
       |> Enum.filter(fn c -> c.attrs[:race] == "plant" end)
       |> Enum.map(fn c -> "#{c.name}" end)

     flora =
       case plants do
         [] -> ""
         names -> "\r\nFlora: " <> Enum.join(names, ", ") <> "."
       end

    players =
      state.occupants
      |> Map.drop([pid])
      |> Map.values()

    presence =
      case players do
        [] -> ""
        names -> "\r\nTambém aqui: " <> Enum.join(names, ", ") <> "."
      end

    exits = "Saídas: #{state.exits |> Map.keys() |> Enum.join(", ")}"

    String.replace(
      """
      == #{state.name} ==
      #{state.description}#{presence}#{flora}
      #{exits}
      """,
      "\n",
      "\r\n"
    )
  end

  defp broadcast(state, message, opts \\ []) do
    except = Keyword.get(opts, :except)

    for {pid, _name} <- state.occupants, pid != except do
      send(pid, {:tell, message})
    end

    :ok
  end
end
