defmodule MudWeb.Layouts do
  use Phoenix.Component
  import Phoenix.Controller, only: [get_csrf_token: 0]

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Mud</title>
        <div id="google_translate_element"></div>
        <div class="lang-buttons">
          <button onclick="translateTo('pt')">🇧🇷</button>
          <button onclick="translateTo('en')">🇺🇸</button>
          <button onclick="translateTo('es')">🇪🇸</button>
          <a href="https://translate.google.com" target="_blank">
            <img src="https://www.gstatic.com/images/branding/product/1x/translate_24dp.png" alt="Google Translate" />
          </a>
        </div>
        <script type="text/javascript">
          function googleTranslateElementInit() {
            new google.translate.TranslateElement(
              { pageLanguage: 'pt', includedLanguages: 'en,es,pt' },
              'google_translate_element'
            );
          }
          function translateTo(lang) {
            const select = document.querySelector('.goog-te-combo')
            if (!select) return
            select.value = lang
            select.dispatchEvent(new Event('change'))
          }
        </script>
        <script src="https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit"></script>
        <script src="/assets/app.js"></script>
        <link rel="stylesheet" href="/assets/app.css" />
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    <div class="page">
      <%= @inner_content %>
    </div>
    """
  end

  def render("mud.html", assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end
end
