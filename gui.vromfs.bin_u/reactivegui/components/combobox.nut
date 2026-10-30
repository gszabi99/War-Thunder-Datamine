






from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, roundPx
from "%rGui/components/text.nut" import mkText, mulAlpha, pictureName
from "%rGui/components/modalWindowsMngr.nut" import addModalWindow, removeModalWindow
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
from "%rGui/components/commonBg.nut" import toColor
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let dpPx = cssConst("dp")
let btnW = cssConst("comboBtnWidth")
let btnH = cssConst("comboBtnHeight")
let smallIconSize = cssConst("cIco")
let optPadX = cssConst("comboOptionPadding")
let blockInterval = cssConst("blockInterval")

let svgSize = cssConst("buttonImgSvgHeight")
let arrowW = roundPx(btnH / 0.55)

function hueBlock(color, size) {
  return {
    size
    margin = [0, 3 * dpPx, 0, 0]
    vplace = ALIGN_CENTER
    rendObj = ROBJ_BOX
    fillColor = toColor($"#{color}")
    borderColor = cssColors.grayOptionColor
    borderWidth = dpPx
  }
}

function optionContent(o, textColor, height) {
  let innerH = height - 2 * dpPx
  let children = []
  foreach (img in o?.images ?? []) {
    let iconSize = img?.iconType == "small" ? smallIconSize : height - dpPx
    children.append({
      size = iconSize
      margin = img?.imageNoMargin ? 0 : [0, blockInterval, 0, 0]
      rendObj = ROBJ_IMAGE
      image = Picture($"{pictureName(img.image)}:{iconSize}:{iconSize}:K")
      keepAspect = KEEP_ASPECT_FIT
    })
  }
  if (o?.hueColor != null)
    children.append(hueBlock(o.hueColor, [3 * innerH + 6 * dpPx, innerH - 6]))
  foreach (c in o?.smallHueColor ?? [])
    children.append(hueBlock(c.color, [innerH, innerH - 6]))
  if ((o?.text ?? "") != "")
    children.append(mkText(o.text, font, textColor, { vplace = ALIGN_CENTER, fontSize = o?.fontSize }))
  return {
    size = [flex(), height]
    padding = [dpPx, optPadX]
    flow = FLOW_HORIZONTAL
    clipChildren = true
    children
  }
}

function listOption(o, idx, key, isCurrent, height, onSelect, onHover) {
  let sf = Watched(0)
  let isEnabled = o?.enabled ?? true
  let tooltip = (o?.tooltip ?? "") == "" ? null : o.tooltip
  let onElemState = tooltip == null ? @(s) sf.set(s) : withHint(sf, key, @() tooltip)
  let onDetach = tooltip == null ? null : tooltipDetach(sf, key)
  
  return @() {
    watch = sf
    key
    size = [flex(), height]
    margin = [dpPx, 0, 0, 0]
    rendObj = ROBJ_SOLID
    color = isCurrent ? cssColors.comboSelOptionColor
      : isEnabled && (sf.get() & S_HOVER) ? cssColors.comboHoverOptionColor
      : cssColors.comboOptionColor
    behavior = isEnabled || tooltip != null ? Behaviors.Button : null
    onElemState
    onDetach
    onHover = onHover == null ? null : @(on) on ? onHover(idx) : null
    onClick = isEnabled ? @() onSelect(idx) : null
    children = optionContent(o, !isEnabled ? 0xFF000000
        : isCurrent ? cssColors.comboExpandedSelTextColor
        : (sf.get() & S_HOVER) ? cssColors.comboExpandedHoverTextColor
        : cssColors.comboExpandedTextColor,
      height)
  }
}

function comboBox(p, state = null, onChange = null, size = null) {
  let id = p?.id
  let options = p?.options ?? []
  let value = state ?? Watched(options.findindex(@(o) o?.selected) ?? 0)
  let sf = Watched(0)
  let { alpha = null, highlight = null, isEnabled = null } = p
  let arrowPic = Picture($"ui/gameuiskin#drop_menu_icon.svg:{svgSize}:{roundPx(svgSize * 0.55)}:K")
  let isExpanded = Watched(false)
  let popupKey = $"comboBox_{id}"
  let hasChoice = options.len() > 1
  let [w, h] = size ?? [cssConst("sliderWidth"), cssConst("baseTrHeight") - 4 * dpPx]

  function close() {
    removeModalWindow(popupKey)
    isExpanded.set(false)
  }

  function select(idx) {
    close()
    if (idx == value.get())
      return
    if (state == null)
      value.set(idx)
    onChange?(id, idx)
  }

  let listH = options.len() * (h + dpPx)
  let popupH = min(listH, sh(100))
  function open(rect) {
    isExpanded.set(true)
    let list = @(innerW, _offset, _viewH) {
      size = [innerW, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = options.map(@(o, idx) listOption(o, idx, $"{popupKey}_{idx}", idx == value.get(), h, select, p?.onHover))
    }
    addModalWindow({
      key = popupKey
      onClick = close
      children = {
        pos = [rect.l, rect.b + popupH <= sh(100) ? rect.b : max(0, rect.t - popupH)]
        rendObj = ROBJ_SOLID
        color = cssColors.comboListBgColor
        stopMouse = true
        children = scrollBox({ size = [rect.r - rect.l, popupH], contentHeight = Watched(listH) }, list)
      }
    })
  }

  let hotkeys = p?.hotkey == null ? null : [[$"^{p.hotkey}"]]
  let watch = [value, sf, isExpanded, alpha, highlight, isEnabled]
  let textSize = [w - btnW, h]
  let arrowSize = [arrowW, btnH]
  let arrowMargin = [0, (btnW - arrowW) / 2]
  return function() {
    let isHover = (sf.get() & S_HOVER) != 0
    let selected = options?[value.get()]
    let isHighlighted = isHover || (highlight?.get() ?? false)
    let enabled = isEnabled?.get() ?? true
    return {
      watch
      key = id
      size = [w, h]
      rendObj = ROBJ_SOLID
      color = mulAlpha(isExpanded.get() ? cssColors.comboExpanedBgColor
          : isHover ? cssColors.comboHoveredBgColor
          : cssColors.comboBgColor,
        alpha?.get() ?? 255)
      behavior = enabled ? Behaviors.Button : null
      skipDirPadNav = p?.skipDirPadNav
      hotkeys
      onElemState = @(s) sf.set(s)
      onDetach = close
      function onClick(evt) {
        soundWt?.playSound("click")
        if (!hasChoice)
          return
        if (isExpanded.get())
          close()
        else
          open(evt.targetRect)
      }
      children = [
        selected == null ? null : optionContent(selected,
          !enabled ? cssColors.disabledTextColor
            : isExpanded.get() ? cssColors.comboExpandedTextColor
            : isHighlighted ? cssColors.hoverTextColor
            : cssColors.commonTextColor,
          h).__update({ size = textSize })
        !enabled || !hasChoice ? null : {
          size = arrowSize
          hplace = ALIGN_RIGHT
          vplace = ALIGN_CENTER
          margin = arrowMargin
          rendObj = ROBJ_IMAGE
          image = arrowPic
          color = cssColors.navButtonImgColor
          opacity = isHover ? 1.0 : 127 / 255.0
          transform = { rotate = isExpanded.get() ? 180 : 0 }
        }
      ]
    }
  }
}

return comboBox
