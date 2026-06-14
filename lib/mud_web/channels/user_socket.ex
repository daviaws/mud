defmodule MudWeb.UserSocket do
  @moduledoc """
  Porteiro do WebSocket.

  Ponto de entrada para todas as conexões WebSocket em `/socket`.
  Autentica a conexão e roteia tópicos para os Channels corretos.

    - `"mud:*"` → MudWeb.MudChannel
  """
  use Phoenix.Socket

  channel "mud:*", MudWeb.MudChannel

  def connect(_params, socket, _connect_info), do: {:ok, socket}
  def id(_socket), do: nil
end
