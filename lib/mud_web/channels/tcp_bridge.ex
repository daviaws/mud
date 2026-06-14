defmodule MudWeb.TcpBridge do
  @moduledoc """
  Conexão TCP com o Mud.Server (ThousandIsland, porta 4040).

  GenServer que mantém um socket TCP aberto e repassa dados entre
  o MudChannel e o servidor de jogo. Completamente ignorante de
  WebSocket — só sabe mandar e receber bytes.

  Usa `active: true` para receber dados TCP como mensagens OTP,
  e `packet: :raw` para entregar chunks imediatamente, sem esperar
  newline — necessário para prompts como "Qual é o seu nome?".

  Um processo por sessão — isolamento total entre conexões.
  """
  use GenServer

  def start_link(channel_pid) do
    GenServer.start_link(__MODULE__, channel_pid)
  end

  def send_input(pid, text) do
    GenServer.cast(pid, {:input, text})
  end

  def init(channel_pid) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4040, [
      :binary,
      active: true,
      packet: :raw
    ])

    {:ok, %{socket: socket, channel_pid: channel_pid}}
  end

  def handle_cast({:input, text}, state) do
    :gen_tcp.send(state.socket, text <> "\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _socket, data}, state) do
    send(state.channel_pid, {:from_mud, data})
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    send(state.channel_pid, {:mud_closed})
    {:noreply, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    send(state.channel_pid, {:mud_error, reason})
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :gen_tcp.close(state.socket)
  end
end
