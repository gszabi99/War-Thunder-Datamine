from "%rGui/globals/ui_library.nut" import *
let tankGunsAmmo = require("%rGui/hud/tankGunsAmmo.nut")
let { actionBarSize, actionBarPos, isActionBarVisible,
  isActionBarCollapsed, isActionBarCollapsable, actionBarCollapseShText
} = require("%rGui/hud/actionBarState.nut")
let { eventbus_send } = require("eventbus")
let fontsState = require("%rGui/style/fontsState.nut")
let { bh } = require("%rGui/style/screenState.nut")
let { isTank } = require("%rGui/hudUnitType.nut")
let { isVisibleTankGunsAmmoIndicator } = require("%rGui/options/options.nut")

let panelMarginBottom = shHud(0.6)
let panelHeight = hdpx(60)
let collapseIconWidth = hdpx(8)
let collapseIconHeight = hdpx(14)
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

let shortcutText = @() {
  watch = actionBarCollapseShText
  rendObj = ROBJ_TEXT
  font = fontsState.get("tiny")
  color = Color(190, 165, 75)
  text = actionBarCollapseShText.get()
}

let collapseButton = watchElemState(@(sf) {
  behavior = Behaviors.Button
  rendObj = ROBJ_9RECT
  image = Picture($"ui/gameuiskin#block_bg_rounded_gray")
  texOffs = 4
  screenOffs = 4
  flow = FLOW_HORIZONTAL
  padding = [hdpx(3), hdpx(7)]
  gap = hdpx(4)
  color = (sf & S_ACTIVE) ? Color(170, 170, 170, 192)
    : (sf & S_HOVER) ? Color(230, 230, 230, 192)
    : Color(192, 192, 192, 192)
  onClick = @() eventbus_send("collapseActionBar", {})
  valign = ALIGN_CENTER
  children = [
    shortcutText
    collapseIconComp
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

let isCollapsButtonVisible = Computed(@() isActionBarVisible.get() && isActionBarCollapsable.get())

function actionBarTopPanel() {
  let canShowTankGunsAmmo = isTank() && isVisibleTankGunsAmmoIndicator.get()

  return {
    watch = [panelY, panelWidth, isCollapsButtonVisible, isActionBarCollapsed, isVisibleTankGunsAmmoIndicator]
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    size = [panelWidth.get(), panelHeight]
    halign = ALIGN_CENTER
    valign = ALIGN_BOTTOM
    padding = [0, hdpx(4), 0, hdpx(8)]

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

return actionBarTopPanel