local isHudVisible = ::Watched(::is_hud_visible())

// Called from client
::on_show_hud <- function on_show_hud(show = true)
{
  isHudVisible(show)
  ::handlersManager.getActiveBaseHandler()?.onShowHud(show, true)
  ::broadcastEvent("ShowHud", { show = show })
}

return {
  isHudVisible
}
