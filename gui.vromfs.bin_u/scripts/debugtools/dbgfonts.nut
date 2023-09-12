//-file:plus-string
from "%scripts/dagui_library.nut" import *

// warning disable: -file:forbidden-function

let fonts = require("fonts")
let { register_command } = require("console")
let debugWnd = require("%scripts/debugTools/debugWnd.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let function debug_change_font_size(shouldIncrease = true) {
  let availableFonts = ::g_font.getAvailableFonts()
  let curFont = ::g_font.getCurrent()
  local idx = availableFonts.findindex(@(v) v == curFont) ?? 0
  idx = clamp(idx + (shouldIncrease ? 1 : -1), 0, availableFonts.len() - 1)
  if (::g_font.setCurrent(availableFonts[idx]))
    handlersManager.getActiveBaseHandler().fullReloadScene()
  dlog($"Loaded fonts: {availableFonts[idx].id}")
}

local fontsAdditionalText = ""
let function debug_fonts_list(isActiveColor = true, needBorder = true) {
  let getColor = @() isActiveColor ? "activeTextColor" : "commonTextColor"

  let view = {
    color = "@" + getColor()
    isActiveColor = isActiveColor
    needBorder = needBorder
    fontsAdditionalText = fontsAdditionalText

    textsList = fonts.getFontsList().map(@(name) { id = name font = name text = "".concat(name, fontsAdditionalText) })
  }

  local handler = {
    scene = null
    guiScene = null

    function onCreate(obj) {
      this.scene = obj
      this.guiScene = obj.getScene()
    }

    function updateAllObjs(func) {
      this.guiScene.setUpdatesEnabled(false, false)
      foreach (id in fonts.getFontsList()) {
        let obj = this.scene.findObject(id)
        if (checkObj(obj))
          func(obj)
      }
      this.guiScene.setUpdatesEnabled(true, true)
    }

    function onColorChange(obj) {
      isActiveColor = obj.getValue()
      let color = this.guiScene.getConstantValue(getColor())
      this.updateAllObjs(function(o) { o.color = color })
    }

    function onBorderChange(obj) {
      needBorder = obj.getValue()
      let borderText = needBorder ? "yes" : "no"
      this.updateAllObjs(function(o) { o.border = borderText })
    }

    function onTextChange(obj) {
      let text = obj.getValue()
      fontsAdditionalText = text.len() ? "\n" + text : ""
      this.updateAllObjs(function(o) { o.setValue(o.id + fontsAdditionalText) })
    }
  }

  debugWnd("%gui/debugTools/fontsList.tpl", view, handler)
}

register_command(@() debug_change_font_size(), "debug.font_size_increase")
register_command(@() debug_change_font_size(false), "debug.font_size_decrease")
register_command(@() debug_fonts_list(), "debug.fonts_list")
register_command(debug_fonts_list, "debug.fonts_list_with_params")
