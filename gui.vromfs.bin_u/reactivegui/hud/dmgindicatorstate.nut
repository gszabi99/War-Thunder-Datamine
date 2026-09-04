from "%rGui/options/options.nut" import damageIndicatorScale
from "%rGui/hud/actionBarState.nut" import actionBarSize, isActionBarVisible
from "%rGui/style/screenState.nut" import safeAreaSizeHud
from "%rGui/hudState.nut" import isSpectatorMode, unitType, needShowDmgIndicator
from "%sqstd/underscore.nut" import isEqual
from "math" import round
from "eventbus" import eventbus_send
from "%rGui/globals/ui_library.nut" import *

let maxDmgIndicatorWidth = Computed(@() round((safeAreaSizeHud.get().size[0] - (isActionBarVisible.get() ? (actionBarSize.get()?[0] ?? 0) : 0)) / 2 - shHud(0.3)))

let dmgIndicatorWidth = Computed(@() isSpectatorMode.get()
  ? shHud(15)
  : unitType.get() == "aircraft" || unitType.get() == "helicopter"
    ? min(round(shHud(30*0.62) * damageIndicatorScale.get()), maxDmgIndicatorWidth.get())
    : min(round(shHud(30) * damageIndicatorScale.get()), maxDmgIndicatorWidth.get())
)

let dmgIndicatorPos = Watched([0, 0])

function updateDmgIndicatorPos(value) {
  if (isEqual(dmgIndicatorPos.get(), value))
    return
  dmgIndicatorPos.set(value)
}

function updateDmgIndicatorElement(_initial, elem) {
  if (elem.getWidth() > 1 && elem.getHeight() > 1) {
    eventbus_send("update_damage_panel_state", {
      pos = [elem.getScreenPosX(), elem.getScreenPosY()]
      size = [elem.getWidth(), elem.getHeight()]
      visible = needShowDmgIndicator.get()
    })
    updateDmgIndicatorPos([elem.getScreenPosX(), elem.getScreenPosY()])
  }
  else
    eventbus_send("update_damage_panel_state", {})
}

return {
  dmgIndicatorWidth
  dmgIndicatorPos
  updateDmgIndicatorElement
}