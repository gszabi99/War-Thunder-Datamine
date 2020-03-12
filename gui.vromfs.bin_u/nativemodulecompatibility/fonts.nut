return {
  discardLoadedData = function() { //wop_1_71_1_X
    dagor.debug("SQ.discardLoadedData()")
    if ("discard_all_loaded_font_data" in ::getroottable())
      ::discard_all_loaded_font_data()
  }
}
