import "%rGui/hud/humanSquad/hudSquadMembers.nut" as hudSquadMembers
import "%rGui/hud/humanSquad/killMarks.nut" as killMarks
import "%rGui/hud/humanSquad/mkHealth.nut" as mkHealth
import "%rGui/hud/humanSquad/mkStamina.nut" as mkStamina
import "%rGui/hud/humanSquad/sightPresets.nut" as sightPresetsPanel
import "%rGui/chat/voiceChat.nut" as voiceChat
import "%rGui/hudLogs.nut" as hudLogs
from "%rGui/hudState.nut" import isSpectatorMode, unitType, tacticalMapStates
from "%rGui/style/screenState.nut" import rw, rh
from "%rGui/hud/hitMarks.nut" import hitMarks
from "%rGui/hud/humanSquad/humanConst.nut" import weaponBlockGap, healthStateBlockGap
from "%rGui/hudUnitType.nut" import isHuman
from "%rGui/activeOrder.nut" import activeOrderComps
from "%rGui/globals/ui_library.nut" import *

require("%rGui/hud/humanPhysState.nut")

let mkCurWeapon = require("%rGui/hud/humanSquad/mkWeapons.nut")
let mkWeaponsList = require("%rGui/hud/humanSquad/mkWeaponsList.nut")



const leftPanelGap = hdpxi(20)
const smallPadding = hdpxi(4)

let centerPanel = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  size = FLEX
  children = hitMarks
}

let leftPanel = {
  flow = FLOW_VERTICAL
  gap = leftPanelGap
  vplace = ALIGN_BOTTOM
  hplace = ALIGN_LEFT

  children = [
    @() {
      watch = isSpectatorMode
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = !isSpectatorMode.get() ? [
        voiceChat
        activeOrderComps
        hudLogs
      ] : null
    }
    @() {
      watch = unitType
      size = SIZE_TO_CONTENT
      children = isHuman() ? hudSquadMembers : null
    }
    @() {
      watch = tacticalMapStates
      size = [tacticalMapStates.get().size[0], tacticalMapStates.get().size[1] + shHud(2)]
    }
  ]
}

let rightPanel = {
  flow = FLOW_VERTICAL
  vplace = ALIGN_BOTTOM
  hplace = ALIGN_RIGHT
  gap = weaponBlockGap
  children = [
    {
      flow = FLOW_VERTICAL
      gap = healthStateBlockGap
      hplace = ALIGN_RIGHT
      children = [
        {
          hplace = ALIGN_RIGHT
          children = [
            mkHealth
            mkWeaponsList
          ]
        }
        mkStamina
      ]
    }
    mkCurWeapon
  ]
}

let infantryHud = @() {
  watch = [rw, rh]
  size = [rw.get(), rh.get()]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = [
    killMarks
    centerPanel
    sightPresetsPanel
    leftPanel
    rightPanel
  ]
}

return {
  infantryHudLeftPanel = leftPanel
  infantryHud
}