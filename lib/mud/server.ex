defmodule Mud.Server do
  @moduledoc """
  Um processo por conexão telnet. Mantém o estado do jogador e traduz
  bytes do socket em comandos. Mensagens vindas das salas chegam como
  `{:tell, msg}` em `handle_info/2`.
  """
  use ThousandIsland.Handler

  alias ThousandIsland.Socket

  @impl ThousandIsland.Handler
  def handle_connection(socket, _state) do
    Socket.send(socket, "Bem-vindo ao mundo.\r\nQual é o seu nome? ")
    {:continue, %{stage: :login, name: nil, room: nil, buffer: ""}}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    {lines, buffer} = extract_lines(state.buffer <> data)

    state =
      Enum.reduce(lines, %{state | buffer: buffer}, fn line, acc ->
        handle_line(String.trim(line), socket, acc)
      end)

    if lines != [] and state.stage == :playing do
      Socket.send(socket, prompt(state))
    end

    {:continue, state}
  end

  # Broadcast de uma sala. ThousandIsland entrega `{socket, state}`.
  @impl GenServer
  def handle_info({:tell, message}, {socket, state}) do
    Socket.send(socket, "\r\n" <> message <> prompt(state))
    {:noreply, {socket, state}}
  end

  ## Linha de input

  defp handle_line(name, socket, %{stage: :login} = state) do
    case String.trim(name) do
      "" ->
        Socket.send(socket, "Nome inválido. Qual é o seu nome? ")
        state

      name ->
        desc = Mud.Room.enter(Mud.World.start_room(), name)
        Socket.send(socket, "\r\n" <> desc)
        %{state | stage: :playing, name: name, room: Mud.World.start_room()}
    end
  end

  defp handle_line(line, socket, %{stage: :playing} = state) do
    case Mud.Command.parse(line) do
      :empty ->
        state

      :look ->
        Socket.send(socket, Mud.Room.look(state.room))
        state

      {:say, text} ->
        Mud.Room.say(state.room, state.name, text)
        Socket.send(socket, "Você diz: #{text}\r\n")
        state

      {:move, dir} ->
        move(state, dir, socket)

      :quit ->
        Socket.send(socket, "Até a próxima.\r\n")
        Socket.close(socket)
        state

      :unknown ->
        Socket.send(
          socket,
          "Não entendi. Tente: olhar, dizer <algo>, norte/sul/leste/oeste, sair.\r\n"
        )

        state
    end
  end

  defp move(state, dir, socket) do
    case Mud.Room.exit_to(state.room, dir) do
      {:ok, dest} ->
        Mud.Room.leave(state.room)
        desc = Mud.Room.enter(dest, state.name)
        Socket.send(socket, desc)
        %{state | room: dest}

      :error ->
        Socket.send(socket, "Não há saída nessa direção.\r\n")
        state
    end
  end

  ## Helpers

  # Telnet manda linhas terminadas em CRLF. Acumulamos parciais no buffer.
  defp extract_lines(data) do
    parts = String.split(data, "\n")
    {complete, [rest]} = Enum.split(parts, -1)
    lines = Enum.map(complete, &String.trim_trailing(&1, "\r"))
    {lines, rest}
  end

  defp prompt(%{stage: :playing}), do: "\r\n> "
  defp prompt(_), do: ""
end
