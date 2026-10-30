



from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
import "%rGui/components/button.nut" as button
import "%rGui/components/editBox.nut" as editBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors
import "%rGui/control/gui_buttons.nut" as JB

let soundWt = require_optional("sound_wt")

let fontNormal = fontsState.get("normal")
let fontBigBold = fontsState.get("bigBold")

let dpPx = cssConst("dp")
let blockInterval = cssConst("blockInterval")
let framePadding = cssConst("framePadding")
let frameTopPadding = cssConst("frameTopPadding")
let navBarH = cssConst("frameFooterHeight")
let headerH = cssConst("frameHeaderHeight")
let headerPad = cssConst("frameHeaderPad")
let bottomPanelH = cssConst("bottomMenuPanelHeight")
let closeBtnH = cssConst("buttonCloseHeight")
let btnH = cssConst("buttonHeight")
let btnMargin = cssConst("buttonMargin")
let iconSize = cssConst("cIco")
let navBarTopPadding = cssConst("navBarTopPadding")


let frameW = px("@rw")
let frameH = px("@rh") - bottomPanelH
let frameInnerW = frameW - 2 * framePadding
let contentTop = frameTopPadding + headerH + dpPx
let frameContentH = @(contentPad = [0, 0]) frameH - contentTop - navBarH + dpPx - contentPad[0] - contentPad[1]

let breadcrumbBar = { rendObj = ROBJ_TEXT, font = fontNormal, color = cssColors.commonMenuButtonColor, text = " | " }

function breadcrumb(title, backSceneName, onBack) {
  let backArrowPic = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{iconSize}:{iconSize}:K")
  let titleText = { rendObj = ROBJ_TEXT, font = fontBigBold, color = cssColors.activeTextColor, text = title }
  let content = @(sf, _isEnabled, _textColor) function() {
    let color = (sf & S_HOVER) != 0 ? cssColors.activeTextColor : cssColors.commonMenuButtonColor
    return {
      watch = backSceneName
      size = const [SIZE_TO_CONTENT, flex()]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = [
        { size = iconSize, rendObj = ROBJ_IMAGE, image = backArrowPic, color, transform = const { rotate = 270 } }
        { rendObj = ROBJ_TEXT, font = fontNormal, color, text = backSceneName.get() }
        breadcrumbBar
        titleText
      ]
    }
  }
  return button({ id = "breadcrumb", visualStyle = "noBgr", size = [SIZE_TO_CONTENT, headerH], margin = 0, content },
    onBack)
}

function closeButton(onBack) {
  let closePic = Picture($"ui/gameuiskin#btn_close.svg:{closeBtnH}:{closeBtnH}:K")
  let sf = Watched(0)
  return @() {
    watch = sf
    size = closeBtnH
    hplace = ALIGN_RIGHT
    margin = headerPad
    rendObj = ROBJ_IMAGE
    image = closePic
    behavior = Behaviors.Button
    hotkeys = [["Esc | {0}".subst(JB.B)]]
    onElemState = @(s) sf.set(s)
    function onClick() {
      soundWt?.playSound("click")
      onBack()
    }
    children = (sf.get() & (S_HOVER | S_ACTIVE)) == 0 ? null : {
      size = flex()
      rendObj = ROBJ_SOLID
      color = (sf.get() & S_ACTIVE) ? cssColors.buttonCloseColorPushed : cssColors.buttonCloseColorHover
    }
  }
}

let navRow = @(children, hplace) { hplace, vplace = ALIGN_CENTER, flow = FLOW_HORIZONTAL, gap = btnMargin, children }

function wndFrame(p) {
  let { title, backSceneName, onBack, tabs = null, content, contentPad = [0, 0], navLeft = [], navRight = [] } = p
  return {
    size = [sw(100), sh(100) - bottomPanelH]
    children = {
      size = [frameW, frameH]
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children = [
        {
          size = [flex(), headerH]
          children = [
            { pos = [btnMargin, 0], children = breadcrumb(title, backSceneName, onBack) }
            closeButton(onBack)
          ]
        }
        tabs == null ? null : { pos = [framePadding, frameTopPadding], children = tabs }
        { size = [frameInnerW, dpPx], pos = [framePadding, contentTop - dpPx], rendObj = ROBJ_SOLID,
          color = cssColors.separatorBlockColor }
        {
          pos = [framePadding, contentTop + contentPad[0]]
          size = [frameInnerW, frameContentH(contentPad)]
          children = content
        }
        {
          pos = [framePadding, frameH - navBarH]
          size = [frameInnerW, navBarH]
          padding = [navBarTopPadding, 0, 0, 0]
          children = [
            { size = [flex(), dpPx], pos = [0, blockInterval - navBarTopPadding], rendObj = ROBJ_SOLID,
              color = cssColors.frameSeparatorColor }
            navRow(navLeft, ALIGN_LEFT)
            navRow(navRight, ALIGN_RIGHT)
          ]
        }
      ]
    }
  }
}

let searchPad = px("2@blockInterval")
let searchBoxH = 2 * searchPad + btnH

let searchBox = @(textW, onSearch, onCancel) {
  size = [flex(), searchBoxH]
  padding = [searchPad, px("0.075@sf") + searchPad]
  children = editBox({ id = "filter_edit_box", editHint = loc("contacts/search_placeholder"),
    onCancel = @(_) onCancel() }, textW, @(_id, text) onSearch(text), [flex(), btnH])
}

return freeze({
  wndFrame
  closeButton
  frameInnerW
  frameContentH
  searchBox
  searchBoxH
})
