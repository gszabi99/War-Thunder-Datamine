::g_options <- {
  needCheckUnitSpeechLangPack = false
}

g_options.onEventActiveHandlersChanged <- function onEventActiveHandlersChanged(params)
{
  if (needCheckUnitSpeechLangPack)
  {
    local handler = ::get_cur_base_gui_handler()
    handler.guiScene.performDelayed(
        handler,
        function() {
          ::check_speech_country_unit_localization_package_and_ask_download()
        }
      )
    ::g_options.needCheckUnitSpeechLangPack = false
  }
}

::subscribe_handler(::g_options, ::g_listener_priority.DEFAULT_HANDLER)