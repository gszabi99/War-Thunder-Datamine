from "%rGui/globals/ui_library.nut" import *

require("%rGui/hud/humanPhysState.nut")

let { isSpectatorMode, unitType, tacticalMapStates } = require("%rGui/hudState.nut")
let { rw, rh } = require("%rGui/style/screenState.nut")
let hudSquadMembers = require("%rGui/hud/humanSquad/hudSquadMembers.nut")
let { hitMarks } = require("%rGui/hud/humanSquad/hitMarks.nut")
let killMarks = require("%rGui/hud/humanSquad/killMarks.nut")
let mkHealth = require("%rGui/hud/humanSquad/mkHealth.nut")
let mkStamina = require("%rGui/hud/humanSquad/mkStamina.nut")
let mkCurWeapon = require("%rGui/hud/humanSquad/mkWeapons.nut")
let mkEquipment = require("%rGui/hud/humanSquad/mkEquipment.nut")
let { weaponBlockGap, healthStateBlockGap } = require("%rGui/hud/humanSquad/humanConst.nut")
let { isHuman } = require("%rGui/hudUnitType.nut")

let activeOrder = require("%rGui/activeOrder.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let hudLogs = require("%rGui/hudLogs.nut")

let leftPanelGap = hdpxi(20)
let smallPadding = hdpxi(4)

let centerPanel = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  size = flex()
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
        activeOrder
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
        mkHealth
        mkStamina
      ]
    }
    {
      flow = FLOW_HORIZONTAL
      gap = weaponBlockGap
      children = [
        mkEquipment
        mkCurWeapon
      ]
    }
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
    leftPanel
    rightPanel
  ]
}

return {
  infantryHudLeftPanel = leftPanel
  infantryHud
}