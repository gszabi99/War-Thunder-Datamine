from "%rGui/globals/ui_library.nut" import *
let tankGunsAmmo = require("%rGui/hud/tankGunsAmmo.nut")
let { actionBarSize, actionBarPos, isActionBarVisible, collapseBtnPressedTime,
  isActionBarCollapsed, isActionBarCollapsable, actionBarCollapseShText, isCollapseBtnHidden,
  isCollapseHintVisible
} = require("%rGui/hud/actionBarState.nut")
let { eventbus_send } = require("eventbus")
let fontsState = require("%rGui/style/fontsState.nut")
let { bh } = require("%rGui/style/screenState.nut")
let { isTank } = require("%rGui/hudUnitType.nut")
let { isVisibleTankGunsAmmoIndicator } = require("%rGui/options/options.nut")
let { isUnitAlive, isPlayingReplay } = require("%rGui/hudState.nut")
let { isRadarGamepadNavEnabled } = require("%rGui/radarButtons.nut")

let panelMarginBottom = shHud(0.6)
let panelHeight = hdpx(60)
let collapseIconWidth = hdpx(8)
let collapseTimerSize = hdpx(17)
let collapseIconHeight = hdpx(14)
let collapseButtonPadding = [hdpx(3), hdpx(7)]
let collapseIcon = Picture($"ui/gameuiskin#icon_collapse_action_bar.svg:{collapseIconWidth}:{collapseIconHeight}")

let collapseIconComp = @() {
  watch = isActionBarCollapsed
  rendObj = ROBJ_IMAGE
  size = [collapseIconWidth, collapseIconHeight]
  image = collapseIcon
  transform = {
    rotate = isActionBarCollapsed.get() ? 0 : 180
  }
}

let shortcutText = @() actionBarCollapseShText.get().len() == 0 ? { watch = actionBarCollapseShText }
  : {
    watch = actionBarCollapseShText
    rendObj = ROBJ_TEXT
    font = fontsState.get("tiny")
    color = Color(190, 165, 75)
    padding = const [0, hdpx(4), 0, 0]
    text = actionBarCollapseShText.get()
  }

let collapseBtnTimer = @() {
  watch = collapseBtnPressedTime
  size = [collapseTimerSize, collapseTimerSize]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = 2
  fillColor = 0
  color = Color(255, 255, 255, 177)
  valign = ALIGN_CENTER
  commands = [
    [VECTOR_SECTOR, 50, 50, 35, 35, 0, collapseBtnPressedTime.get() * 359.0],
  ]
}

let isCollapseTimerVisible = Computed(@() collapseBtnPressedTime.get() > 0)

let hintText = {
  rendObj = ROBJ_TEXT
  pos = [collapseButtonPadding[1], -collapseButtonPadding[0]*2 - hdpx(6)]
  font = fontsState.get("tiny")
  color = Color(255, 255, 255)
  text = loc("hud/collapseBtnHoverHint")
}

let hintTextContainer = {
  halign = ALIGN_RIGHT
  pos = [0, ph(-100)]
  size = 0
  children = hintText
}

let collapseButton = watchElemState(@(sf) {
  watch = [isCollapseHintVisible, isCollapseTimerVisible, isRadarGamepadNavEnabled]
  behavior = Behaviors.Button
  rendObj = ROBJ_9RECT
  image = Picture($"ui/gameuiskin#block_bg_rounded_gray")
  texOffs = 4
  screenOffs = 4
  flow = FLOW_HORIZONTAL
  padding = collapseButtonPadding
  color = (sf & S_ACTIVE) ? Color(170, 170, 170, 192)
    : (sf & S_HOVER) ? Color(230, 230, 230, 192)
    : Color(192, 192, 192, 192)
  onClick = @() eventbus_send("collapseActionBar")
  skipDirPadNav = isRadarGamepadNavEnabled.get()
  valign = ALIGN_CENTER
  children = [
    isCollapseTimerVisible.get() ? collapseBtnTimer : null
    !isCollapseTimerVisible.get() ? shortcutText : null
    !isCollapseTimerVisible.get() ? collapseIconComp : null
    isCollapseHintVisible.get() ? hintTextContainer : null
  ]
})

let isActionBarShown = Computed(@() isActionBarVisible.get()
  && (!isActionBarCollapsable.get() || !isActionBarCollapsed.get()))

let panelY = Computed(@() (isActionBarShown.get() && actionBarPos.get() != null)
  ? actionBarPos.get()[1] - panelHeight - panelMarginBottom
  : sh(100) - bh.get() - panelHeight)

let panelWidth = Computed(@() (isActionBarVisible.get() && actionBarSize.get() != null)
  ? actionBarSize.get()[0]
  : 0)

let isCollapsButtonVisible = Computed(@() isActionBarVisible.get() && isActionBarCollapsable.get()
  && (!isCollapseBtnHidden.get() || !isActionBarCollapsed.get()))

function actionBarTopPanel() {
  let canShowTankGunsAmmo = isTank() && isVisibleTankGunsAmmoIndicator.get()
    && !isActionBarCollapsed.get() && isUnitAlive.get() && !isPlayingReplay.get()

  return {
    watch = [panelY, panelWidth, isCollapsButtonVisible,
      isActionBarCollapsed, isVisibleTankGunsAmmoIndicator, isUnitAlive, isPlayingReplay]
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    size = [panelWidth.get(), panelHeight]
    halign = ALIGN_CENTER
    valign = ALIGN_BOTTOM
    padding = const [0, hdpx(6)]

    transform = { translate = [0, panelY.get()] }
    transitions = [{
      prop = AnimProp.translate,
      duration = 0.2,
      easing = isActionBarCollapsed.get() ? InQuad : OutQuad
    }]

    children = [
      canShowTankGunsAmmo ? tankGunsAmmo : null
      isCollapsButtonVisible.get() ? {
        size = flex()
        minWidth = canShowTankGunsAmmo ? hdpx(10) : 0
      } : null
      isCollapsButtonVisible.get() ? collapseButton : null
    ]
  }
}

return {
  actionBarTopPanel
  actionBarTopPanelMarginBottom = panelMarginBottom
  actionBarTopPanelHeight = panelHeight
}
