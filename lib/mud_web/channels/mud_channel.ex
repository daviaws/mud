defmodule MudWeb.MudChannel do
  @moduledoc """
  Intermediário entre o browser e o servidor TCP do MUD.

  Um processo por sessão de browser. Ao entrar no canal, cria um
  `TcpBridge` dedicado que abre uma conexão TCP com o Mud.Server.

  Fluxo:
    browser → handle_in("input") → TcpBridge → TCP → Mud.Server
    Mud.Server → TCP → TcpBridge → handle_info({:from_mud}) → browser

  Ao desconectar, encerra o TcpBridge e fecha o TCP.
  """
  use Phoenix.Channel

  def join("mud:session", _params, socket) do
    {:ok, bridge} = MudWeb.TcpBridge.start_link(self())
    {:ok, assign(socket, bridge: bridge)}
  end

  def handle_in("input", %{"text" => text}, socket) do
    MudWeb.TcpBridge.send_input(socket.assigns.bridge, text)
    {:noreply, socket}
  end

  def handle_info({:from_mud, data}, socket) do
    push(socket, "output", %{text: data})
    {:noreply, socket}
  end

  def handle_info({:mud_closed}, socket) do
    push(socket, "closed", %{})
    {:noreply, socket}
  end

  def handle_info({:mud_error, reason}, socket) do
    push(socket, "error", %{reason: inspect(reason)})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    if bridge = socket.assigns[:bridge] do
      GenServer.stop(bridge)
    end
  end
end
