from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let { eventbus_send } = require("eventbus")
let scrollbar = require("%rGui/components/scrollbar.nut")
let { formatText } = require("%rGui/components/formatText.nut")
let { curPatchnote, curPatchnoteIdx, choosePatchnote, nextPatchNote,
  prevPatchNote, patchnotesReceived, versions, chosenPatchnoteContent,
  chosenPatchnoteLoaded, needShowSteamReviewBtn, isNews, closePatchnote } = require("%rGui/changelog/changeLogState.nut")
let colors = require("%rGui/style/colors.nut")
let { commonTextButton, steamReviewTextButton, buttonHeight
} = require("%rGui/components/textButton.nut")
let modalWindow = require("%rGui/components/modalWindow.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let JB = require("%rGui/control/gui_buttons.nut")
let { mkImageCompByDargKey } = require("%rGui/components/gamepadImgByKey.nut")
let { showConsoleButtons } = require("%rGui/ctrlsState.nut")
let focusBorder = require("%rGui/components/focusBorder.nut")
let { blurPanel } = require("%rGui/components/blurPanel.nut")
let spinner = require("%rGui/components/spinner.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { format } = require("string")
let { steam_get_app_id } = require("steam")

let tabStyle = {
  fillColor = {
    normal   = colors.transparent
    hover    = colors.menu.menuButtonColorHover
    active   = colors.menu.frameBackgroundColor
    current  = colors.menu.higlightFrameBgColor
  }
  textColor = {
    normal   = colors.menu.commonTextColor
    hover    = colors.menu.menuButtonTextColorHover
    active   = colors.menu.activeTextColor
    current  = colors.menu.activeTextColor
  }
}

let blockInterval = fpx(6)
let borderWidth = dp(1)

let scrollHandler = ScrollHandler()
let scrollStep = fpx(75)
let maxPatchnoteWidth = fpx(300)

function getTabColorCtor(sf, style, isCurrent) {
  if (isCurrent)
    return style.current
  if (sf & S_ACTIVE)
    return style.active
  if (sf & S_HOVER)
    return style.hover
  return style.normal
}

function patchnote(v) {
  let stateFlags = Watched(0)
  let isCurrent = Computed(@() curPatchnote.value.id == v.id)
  return @() {
    watch = [stateFlags, isCurrent]
    rendObj = ROBJ_BOX
    fillColor = isCurrent.value ? Color(58, 71, 79)
      : Color(0, 0, 0)
    borderColor = Color(178, 57, 29)
    borderWidth = isCurrent.value ? [0, 0, 2 * borderWidth, 0] : 0
    size = const [flex(1), ph(100)]
    maxWidth = maxPatchnoteWidth
    behavior = Behaviors.Button
    halign = ALIGN_CENTER
    onClick = @() choosePatchnote(v)
    onElemState = @(sf) stateFlags(sf)
    children = [
      {
        size = const [flex(), ph(100)]
        maxWidth = maxPatchnoteWidth - 2 * scrn_tgt(0.01)
        behavior = Behaviors.TextArea
        rendObj = ROBJ_TEXTAREA
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        color = getTabColorCtor(stateFlags.value, tabStyle.textColor, isCurrent.value)
        font = fontsState.get("small")
        text = v?.titleshort ?? v?.title ?? v.tVersion
      },
      (stateFlags.value & S_HOVER) != 0 ? focusBorder({ maxWidth = maxPatchnoteWidth }) : null
    ]
  }
}

let topBorder = @(params = {}) {
  size = [dp(1), flex()]
  valign = ALIGN_CENTER
}.__merge(params)

let patchnoteSelectorGamepadButton = @(hotkey, actionFunc) topBorder({
  size = FLEX_V
  behavior = Behaviors.Button
  children = mkImageCompByDargKey(hotkey)
  onClick = actionFunc
  skipDirPadNav = true
})

let isVersionsExists = Computed(@() patchnotesReceived.get() && !isNews.get() && (versions.get()?.len() ?? 0) > 0)
function getPatchoteSelectorChildren(versionsConf, needAddGamepadButtons) {
  let children = versionsConf.map(patchnote)
  if (!needAddGamepadButtons)
    return children

  return [patchnoteSelectorGamepadButton("J:LB", nextPatchNote)]
    .extend(children)
    .append(patchnoteSelectorGamepadButton("J:RB", prevPatchNote))
}

let patchnoteSelector = @() {
  watch = [versions, showConsoleButtons]
  size = [flex(), buttonHeight + 2*blockInterval]
  flow = FLOW_HORIZONTAL
  gap = topBorder()
  padding = [blockInterval, 0, 0, 0]
  children = getPatchoteSelectorChildren(versions.get(), showConsoleButtons.get())
}

let missedPatchnoteText = formatText([loc("NoUpdateInfo", "Oops... No information yet :(")])

let seeMoreUrl = {
  t = "url"
  url = getCurCircuitOverride("newsURL", loc("url/news"))
  v = loc("visitGameSite", "See game website for more details")
  margin = [fpx(50), 0, 0, 0]
}

let scrollPatchnoteWatch = Watched(0)

function scrollPatchnote() {  
  let element = scrollHandler.elem
  if (element != null)
    scrollHandler.scrollToY(element.getScrollOffsY() + scrollPatchnoteWatch.value * scrollStep)
}

scrollPatchnoteWatch.subscribe(function(value) {
  gui_scene.clearTimer(scrollPatchnote)
  if (value == 0)
    return

  scrollPatchnote()
  gui_scene.setInterval(0.1, scrollPatchnote)
})

let scrollPatchnoteBtn = @(hotkey, watchValue) {
  behavior = Behaviors.Button
  onElemState = @(sf) scrollPatchnoteWatch((sf & S_ACTIVE) ? watchValue : 0)
  hotkeys = [[hotkey]]
  onDetach = @() scrollPatchnoteWatch(0)
}

chosenPatchnoteContent.subscribe(@(_value) scrollHandler.scrollToY(0))

let patchnoteLoading = freeze({
  children = [formatText([{ v = loc("loading"), t = "h2", halign = ALIGN_CENTER }]), spinner]
  flow  = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(20)
  valign = ALIGN_CENTER size = const [flex(), sh(20)]
  padding = sh(2)
})

function selPatchnote() {
  local text = (chosenPatchnoteContent.get().text ?? "") != ""
    ? chosenPatchnoteContent.get().text : missedPatchnoteText
  if (cross_call.hasFeature("AllowExternalLink") && !isNews.get()) {
    if (type(text) != "array")
      text = [text, seeMoreUrl]
    else
      text = (clone text).append(seeMoreUrl)
  }
  return {
    watch = [chosenPatchnoteLoaded, chosenPatchnoteContent, isNews]
    size = flex()
    children = [
      scrollbar.makeSideScroll({
        size = FLEX_H
        margin = [0, blockInterval]
        children = chosenPatchnoteLoaded.value ? formatText(text) : patchnoteLoading
      }, {
        scrollHandler = scrollHandler
        joystickScroll = false
      }),
      scrollPatchnoteBtn("^J:R.Thumb.Up | PageUp", -1),
      scrollPatchnoteBtn("^J:R.Thumb.Down | PageDown", 1)
    ]
  }
}

function onCloseAction() {
  closePatchnote()
  cross_call.startMainmenu()
}

function sendBqSteamReview(reason) {
  eventbus_send("sendBqEvent", {
    tableId = "CLIENT_POPUP_1"
    event = "rate"
    data = { from = "steam", reason }
  })
}

function openSteamReview() {
  eventbus_send("open_url", {
    baseUrl = format(loc("url/steamstore/item"), steam_get_app_id().tostring())
  })
  sendBqSteamReview("pushReviewBtnInChangeLog")
}

let btnNext  = commonTextButton(loc("mainmenu/btnNextItem"), nextPatchNote,
  { hotkeys = [["{0} | Tab".subst(JB.B)]], margin = 0 })
let btnClose = commonTextButton(loc("mainmenu/btnClose"), onCloseAction,
  { hotkeys = [["{0}".subst(JB.B)]], margin = 0 })
let btnSteamReview = steamReviewTextButton(loc("write_review"), openSteamReview,
  { hotkeys = [["J:Y"]], margin = 0, onAttach = @(_) sendBqSteamReview("showReviewBtnInChangeLog") })


let nextButton = @() {
  watch = [curPatchnoteIdx, isNews]
  size = SIZE_TO_CONTENT
  children = !isNews.get() && curPatchnoteIdx.get() != 0 ? btnNext : btnClose
}

let steamReviewButton = @() {
  watch = [needShowSteamReviewBtn]
  size = SIZE_TO_CONTENT
  children = needShowSteamReviewBtn.get() ? btnSteamReview : null
}

let navbar = {
  size = SIZE_TO_CONTENT
  hplace = ALIGN_RIGHT
  gap = blockInterval
  flow = FLOW_HORIZONTAL
  padding = [blockInterval, 0, 0, 0]
  children = [
    steamReviewButton
    nextButton
  ]
}

let clicksHandler = {
  size = flex(),
  eventPassThrough = true,
  skipDirPadNav = true
  behavior = Behaviors.Button
  hotkeys = [
    ["J:LB", nextPatchNote],
    ["J:RB", prevPatchNote]
  ]
}

let changelogRoot = {
  size = flex()
  children = [
    blurPanel
    clicksHandler
    modalWindow({
      content = {
        size = flex()
        margin = blockInterval
        flow = FLOW_VERTICAL
        children = [
          {
            rendObj = ROBJ_BOX
            size = flex()
            flow = FLOW_VERTICAL
            borderColor = colors.menu.separatorBlockColor
            borderWidth = [0, 0, borderWidth, 0]
            padding = [0, 0, blockInterval, 0]
            children = selPatchnote
          }
          @() {
            watch = isVersionsExists
            size = FLEX_H
            flow = FLOW_VERTICAL
            children = [
              isVersionsExists.get() ? patchnoteSelector : null
              navbar
            ]
          }
        ]
      },
      headerParams = {
        closeBtn = { onClick = onCloseAction }
        content = @() {
          watch = chosenPatchnoteContent
          rendObj = ROBJ_TEXT
          font = fontsState.get("medium")
          color = colors.menu.activeTextColor
          text = chosenPatchnoteContent.value.title
          margin = [0, 0, 0, fpx(15)]
        }
      }
    })
  ]
}

return changelogRoot
