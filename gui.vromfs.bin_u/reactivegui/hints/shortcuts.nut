local fontsState = require("reactiveGui/style/fontsState.nut")
local colors = require("reactiveGui/style/colors.nut")

local shortcutsParamsByPlace = @() {
  defaultP = { shortcutAxis = [::shHud(6), ::shHud(6)]
    gamepadButtonSize = [::shHud(4), ::shHud(4)]
    keyboardButtonSize = [SIZE_TO_CONTENT, ::shHud(4)]
    keyboardButtonMinWidth = ::shHud(4)
    keyboardButtonPad = [0, ::hdpx(13)]
    keyboardButtonTextFont = Fonts.medium_text_hud
    combinationGap = ::shHud(1)
  }
  chatHint = { shortcutAxis = [::fpx(30), ::fpx(30)]
    gamepadButtonSize = [::fpx(30), ::fpx(30)]
    keyboardButtonSize = [SIZE_TO_CONTENT, ::fpx(22)]
    keyboardButtonMinWidth = ::fpx(22)
    keyboardButtonPad = [0, ::hdpx(6)]
    keyboardButtonTextFont = fontsState.get("tiny")
    combinationGap = ::fpx(6)
  }
  actionItem = { shortcutAxis = [::shHud(3), ::shHud(3)]
    gamepadButtonSize = [::shHud(3), ::shHud(3)]
    keyboardButtonSize = [SIZE_TO_CONTENT, ::shHud(2)]
    keyboardButtonMinWidth = ::shHud(2)
    keyboardButtonPad = [0, ::hdpx(5)]
    keyboardButtonTextFont = Fonts.very_tiny_text_hud
    combinationGap = 0
  }
}

local hasImage = @(shortcutConfig) shortcutConfig?.buttonImage
  && shortcutConfig?.buttonImage != ""

local function gamepadButton(shortcutConfig, override, isAxis = true) {
  local sizeParam = shortcutsParamsByPlace()[override?.place ?? "defaultP"]
  local buttonSize = isAxis ? sizeParam.shortcutAxis : sizeParam.gamepadButtonSize
  local image = shortcutConfig.buttonImage
  image = image.slice(0, 1) == "#" ? $"!{image.slice(1, image.len())}" : image
  return {
    size = buttonSize
    rendObj = ROBJ_IMAGE
    image = Picture(image)
    color = colors.white
  }
}

local function keyboardButton(shortcutConfig, override) {
  local sizeParam = shortcutsParamsByPlace()[override?.place ?? "defaultP"]
  return {
    size = sizeParam.keyboardButtonSize
    minWidth = sizeParam.keyboardButtonMinWidth
    rendObj = ROBJ_IMAGE
    image = Picture("!ui/gameuiskin#keyboardBtn")
    color = colors.white
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    padding = sizeParam.keyboardButtonPad
    children = [{
      rendObj = ROBJ_DTEXT
      font = sizeParam.keyboardButtonTextFont
      text = shortcutConfig.text
      color = Color(0, 0, 0)
    }]
  }
}

local function arrowImg(direction, override) {

  local img = direction == 0 ? "ui/gameuiskin#cursor_size_hor" : "ui/gameuiskin#cursor_size_vert"
  return {
    rendObj = ROBJ_IMAGE
    size = [::fpx(30), ::fpx(30)]
    image = ::Picture($"!{img}")
    color = colors.white
  }
}

local getShortcut = @(shortcutConfig, override) null

local shortcutByInputName = {
  axis = @(shortcutConfig, override) hasImage(shortcutConfig)
      ? gamepadButton(shortcutConfig, override)
      : keyboardButton(shortcutConfig, override)

  button = @(shortcutConfig, override) hasImage(shortcutConfig)
      ? gamepadButton(shortcutConfig, override, false)
      : keyboardButton(shortcutConfig, override)

  combination = function(shortcutConfig, override) {
    local sizeParam = shortcutsParamsByPlace()[override?.place ?? "defaultP"]
    local elmementsCount = shortcutConfig.elements.len()
    local sortcutsCombination = []
    foreach(idx, element in shortcutConfig.elements) {
      sortcutsCombination.append(getShortcut(element, override))
      if(idx < elmementsCount-1)
        sortcutsCombination.append({
          rendObj = ROBJ_DTEXT
          font = sizeParam.keyboardButtonTextFont
          text = "+"
          color = colors.menu.commonTextColor
        })
    }
    return {
      size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      gap = sizeParam.combinationGap
      children = sortcutsCombination
    }
  }

  doubleAxis = @(shortcutConfig, override) gamepadButton(shortcutConfig, override)

  inputImage = @(shortcutConfig, override) gamepadButton(shortcutConfig, override, false)

  inputBase = @(shortcutConfig, override) null

  keyboardAxis = function(shortcutConfig, override) {
    local needArrows = shortcutConfig?.needArrows ?? false
    local sizeParam = shortcutsParamsByPlace()[override?.place ?? "defaultP"]
    return {
      size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER

      children = [{
        size = [SIZE_TO_CONTENT, flex()]
        valign = needArrows ? ALIGN_CENTER : ALIGN_BOTTOM
        children = [getShortcut(shortcutConfig.elements?.leftKey, override)]
      },
      {
        size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = [
          getShortcut(shortcutConfig.elements?.topKey, override),
          needArrows
            ? {
                size = sizeParam.gamepadButtonSize
                valign = ALIGN_CENTER
                halign = ALIGN_CENTER
                children = shortcutConfig.arrows.map(@(arrow) arrowImg(arrow.direction, override))
              }
            : null,
          getShortcut(shortcutConfig.elements?.downKey, override)]
      },
      {
        size = [SIZE_TO_CONTENT, flex()]
        valign = needArrows ? ALIGN_CENTER : ALIGN_BOTTOM
        children = [getShortcut(shortcutConfig.elements?.rightKey, override)]
      }]
    }
  }

  nullInput = @(shortcutConfig, override) shortcutConfig.showPlaceholder
      ? {
        rendObj = ROBJ_DTEXT
        font = Fonts.medium_text_hud
        text = shortcutConfig.text
      }.__update(override)
      : null
}

getShortcut = function(shortcutConfig, override) {
  return shortcutByInputName?[shortcutConfig?.inputName ?? ""]?(shortcutConfig, override)
}

return getShortcut