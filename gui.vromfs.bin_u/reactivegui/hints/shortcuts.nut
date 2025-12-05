from "%rGui/globals/ui_library.nut" import *

let fontsState = require("%rGui/style/fontsState.nut")
let { getFontName } = require("fonts")
let colors = require("%rGui/style/colors.nut")

let antiAirMenuShortcutHeight = evenPx(30)

let actionItemParams = { shortcutAxis = [shHud(3), shHud(3)]
  gamepadButtonSize = [shHud(3), shHud(3)]
  keyboardButtonSize = [SIZE_TO_CONTENT, shHud(2)]
  keyboardButtonMinWidth = shHud(2)
  keyboardButtonPad = [0, hdpx(5)]
  keyboardButtonTextFont = Fonts.very_tiny_text_hud
  combinationGap = 0
  shColor = colors.actionBarHotkeyColor
  bgImage = "ui/gameuiskin#block_bg_rounded_gray"
  bgImageColor = Color(255, 255, 255, 192)
  texOffs = 4
  screenOffs = 4
}

let shortcutsParamsByPlace = @(scale = 1) {
  defaultP = { shortcutAxis = [shHud(6), shHud(6)]
    gamepadButtonSize = [shHud(4), shHud(4)]
    keyboardButtonSize = [SIZE_TO_CONTENT, shHud(4)]
    keyboardButtonMinWidth = shHud(4)
    keyboardButtonPad = [0, hdpx(13)]
    keyboardButtonTextFont = Fonts.medium_text_hud
    combinationGap = shHud(1)
  }
  chatHint = { shortcutAxis = [fpx(30), fpx(30)]
    gamepadButtonSize = [fpx(30), fpx(30)]
    keyboardButtonSize = [SIZE_TO_CONTENT, fpx(22)]
    keyboardButtonMinWidth = fpx(22)
    keyboardButtonPad = [0, hdpx(6)]
    keyboardButtonTextFont = fontsState.get("tiny")
    combinationGap = fpx(6)
  }
  antiAirMenu = { shortcutAxis = [antiAirMenuShortcutHeight * scale, antiAirMenuShortcutHeight * scale]
    gamepadButtonSize = [antiAirMenuShortcutHeight * scale, antiAirMenuShortcutHeight * scale]
    keyboardButtonSize = [SIZE_TO_CONTENT, 2 * (0.45 * antiAirMenuShortcutHeight * scale + 0.5).tointeger()]
    keyboardButtonMinWidth = evenPx(36)
    keyboardButtonPad = [0, hdpx(5)]
    keyboardButtonTextFont = Fonts.tiny_text_hud
    combinationGap = hdpx(5)
  }
  actionItem = actionItemParams
  airParamsTable = actionItemParams.__merge({
    gamepadButtonSize = [shHud(2), shHud(2)]
  })
  actionItemInfantry = {
    shortcutAxis = [antiAirMenuShortcutHeight, antiAirMenuShortcutHeight]
    gamepadButtonSize = [antiAirMenuShortcutHeight, antiAirMenuShortcutHeight]
    keyboardButtonSize = SIZE_TO_CONTENT
    keyboardButtonMinWidth = evenPx(22)
    keyboardButtonPad = [0, hdpx(5)]
    keyboardButtonTextFont = Fonts.tiny_text_hud
    combinationGap = hdpx(5)
    bgImage = $"ui/gameuiskin#shortcut_flat.svg:{antiAirMenuShortcutHeight}:P"
  }
}

let hasImage = @(shortcutConfig) shortcutConfig?.buttonImage
  && shortcutConfig?.buttonImage != ""

function gamepadButton(shortcutConfig, override, isAxis = true, addChildrend = []) {
  let { scale = 1, place = "defaultP" } = override
  let sizeParam = shortcutsParamsByPlace(scale)[place]
  let buttonSize = isAxis ? sizeParam.shortcutAxis : sizeParam.gamepadButtonSize
  local image = shortcutConfig.buttonImage
  image = image.slice(0, 1) == "#" ? $"!{image.slice(1, image.len())}" : image
  let children = {
    size = buttonSize
    rendObj = ROBJ_IMAGE
    image = Picture(image)
    color = colors.white
    keepAspect = true
  }
  return addChildrend.len() == 0 ? children
    : {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        gap = sizeParam.combinationGap
        children = [children].extend(addChildrend)
      }
}

function keyboardButton(shortcutConfig, override, addChildrend = []) {
  let { scale = 1, place = "defaultP", shortCombinationMinWidth = null,
    shortCombination = false } = override
  let shortcutsParams = shortcutsParamsByPlace(scale)[place]
  let { keyboardButtonSize, keyboardButtonMinWidth, keyboardButtonPad, keyboardButtonTextFont
    shColor = override?.shColor ?? colors.menu.commonTextColor,
    bgImage = null
    bgImageColor = override?.bgImageColor ?? colors.white
    texOffs = [0, hdpx(10)]
    screenOffs = [0, hdpx(10)]
  } = shortcutsParams
  let kbBgImage = bgImage ?? $"ui/gameuiskin#keyboard_btn_flat.svg:{keyboardButtonSize[1]}:P"
  let ch = {
    rendObj = ROBJ_TEXT
    font = keyboardButtonTextFont
    fontSize = getFontDefHt(getFontName(keyboardButtonTextFont)) * scale
    text = shortcutConfig.text
    color = shColor
  }
  let children = addChildrend.len() == 0 ? ch : [ch].extend(addChildrend)
  let minWidth = shortCombination && shortCombinationMinWidth != null
    ? shortCombinationMinWidth
    : keyboardButtonMinWidth
  return {
    size = keyboardButtonSize
    minWidth
    rendObj = ROBJ_9RECT
    flow = FLOW_HORIZONTAL
    image = Picture(kbBgImage)
    color = bgImageColor
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    padding = keyboardButtonPad
    gap = hdpxi(5)
    texOffs
    screenOffs
    children
  }
}

function arrowImg(direction, _override) {

  let img = direction == 0 ? "ui/gameuiskin#cursor_size_hor.svg" : "ui/gameuiskin#cursor_size_vert.svg"
  return {
    rendObj = ROBJ_IMAGE
    size = [fpx(30), fpx(30)]
    image = Picture($"!{img}")
    color = colors.white
  }
}

local getShortcut = @(_shortcutConfig, _override, _addChildrend) null

let shortcutByInputName = {
  axis = @(shortcutConfig, override, addChildrend = []) hasImage(shortcutConfig)
      ? gamepadButton(shortcutConfig, override, true, addChildrend)
      : keyboardButton(shortcutConfig, override, addChildrend)

  button = @(shortcutConfig, override, addChildrend = []) hasImage(shortcutConfig)
      ? gamepadButton(shortcutConfig, override, false, addChildrend)
      : keyboardButton(shortcutConfig, override, addChildrend)

  combination = function(shortcutConfig, override, addChildrend = []) {
    let { scale = 1, place = "defaultP", shortCombination = false } = override
    let sizeParam = shortcutsParamsByPlace(scale)[place]
    let elmementsCount = shortcutConfig.elements.len()
    let shortcutsCombination = []
    if (!shortCombination) {
      foreach (idx, element in shortcutConfig.elements) {
        shortcutsCombination.append(getShortcut(element, override, addChildrend))
        if (idx < elmementsCount - 1)
          shortcutsCombination.append({
            rendObj = ROBJ_TEXT
            font = sizeParam.keyboardButtonTextFont
            fontSize = getFontDefHt(getFontName(sizeParam.keyboardButtonTextFont)) * scale
            text = "+"
            color = colors.menu.commonTextColor
          })
      }
    }
    else {
      shortcutsCombination.append(getShortcut({inputName = "button",
        text = shortcutConfig.text.replace(" + ", "+")}, override, addChildrend))
    }


    if (addChildrend.len())
      shortcutsCombination.extend(addChildrend)

    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      gap = sizeParam.combinationGap
      children = shortcutsCombination
    }
  }

  doubleAxis = @(shortcutConfig, override, _addChildrend) gamepadButton(shortcutConfig, override, true)

  inputImage = @(shortcutConfig, override, _addChildrend) gamepadButton(shortcutConfig, override, false)

  inputBase = @(_shortcutConfig, _override, _addChildrend) null

  keyboardAxis = function(shortcutConfig, override, addChildrend) {
    let needArrows = shortcutConfig?.needArrows ?? false
    let { scale = 1, place = "defaultP" } = override
    let sizeParam = shortcutsParamsByPlace(scale)[place]
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER

      children = [{
        size = FLEX_V
        valign = needArrows ? ALIGN_CENTER : ALIGN_BOTTOM
        children = [getShortcut(shortcutConfig.elements?.leftKey, override, addChildrend)]
      },
      {
        size = SIZE_TO_CONTENT
        flow = FLOW_VERTICAL
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = [
          getShortcut(shortcutConfig.elements?.topKey, override, addChildrend),
          needArrows
            ? {
                size = sizeParam.gamepadButtonSize
                valign = ALIGN_CENTER
                halign = ALIGN_CENTER
                children = shortcutConfig.arrows.map(@(arrow) arrowImg(arrow.direction, override))
              }
            : null,
          getShortcut(shortcutConfig.elements?.downKey, override, addChildrend)]
      },
      {
        size = FLEX_V
        valign = needArrows ? ALIGN_CENTER : ALIGN_BOTTOM
        children = [getShortcut(shortcutConfig.elements?.rightKey, override, addChildrend)]
      }]
    }
  }

  nullInput = @(shortcutConfig, override, _addChildrend) shortcutConfig.showPlaceholder
      ? {
        rendObj = ROBJ_TEXT
        font = Fonts.medium_text_hud
        text = shortcutConfig.text
      }.__update(override)
      : null
}

getShortcut = function(shortcutConfig, override, addChildrend = []) {
  return shortcutByInputName?[shortcutConfig?.inputName ?? ""]?(shortcutConfig, override, addChildrend)
}

return {
  getShortcut
  antiAirMenuShortcutHeight
}