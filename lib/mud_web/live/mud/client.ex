defmodule MudWeb.MudLive.Client do
  use MudWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, connected: false), layout: {MudWeb.Layouts, :mud}}
  end

  def render(assigns) do
    ~H"""
    <div class="mud-client" id="mud-client" phx-hook="MudClient">
      <aside class="mud-left">
        <div class="mud-panel">
          <h3>Personagem</h3>
          <div id="character-info" phx-update="ignore">
            <p class="muted">Conectando...</p>
          </div>
        </div>
      </aside>

      <main class="mud-main" id="mud-main" phx-update="ignore">
        <div class="mud-log" id="mud-log">
          <div id="mud-log-content"></div>
        </div>
        <div class="mud-input">
          <div class="mud-history-list" id="mud-history" style="display:none"></div>
          <div class="mud-input-row">
            <span class="mud-prompt">&gt;</span>
            <input
              type="text"
              id="mud-cmd"
              autocomplete="off"
              spellcheck="false"
              placeholder="comando..."
            />
          </div>
        </div>
      </main>

      <aside class="mud-right" id="mud-right" phx-update="ignore">
        <div class="mud-panel mud-room">
          <h3>Sala</h3>
          <div id="room-desc"><p class="muted">—</p></div>
        </div>
        <div class="mud-panel mud-says">
          <h3>Dito aqui</h3>
          <div id="room-says"></div>
        </div>
      </aside>
    </div>
    """
  end
end
