from "%rGui/globals/ui_library.nut" import *

require("%rGui/hud/humanPhysState.nut")

let { isSpectatorMode, unitType, tacticalMapStates } = require("%rGui/hudState.nut")
let { rw, rh } = require("%rGui/style/screenState.nut")
let { totalDomTeam, totalDomMult, totalDomNextMult, totalDomSecLeft, localTeam
} = require("%rGui/missionState.nut")
let teamColors = require("%rGui/style/teamColors.nut")
let string = require("string")
let hudSquadMembers = require("%rGui/hud/humanSquad/hudSquadMembers.nut")
let { hitMarks } = require("%rGui/hud/hitMarks.nut")
let killMarks = require("%rGui/hud/humanSquad/killMarks.nut")
let mkHealth = require("%rGui/hud/humanSquad/mkHealth.nut")
let mkStamina = require("%rGui/hud/humanSquad/mkStamina.nut")
let mkCurWeapon = require("%rGui/hud/humanSquad/mkWeapons.nut")
let mkWeaponsList = require("%rGui/hud/humanSquad/mkWeaponsList.nut")
let sightPresetsPanel = require("%rGui/hud/humanSquad/sightPresets.nut")
let { weaponBlockGap, healthStateBlockGap } = require("%rGui/hud/humanSquad/humanConst.nut")
let { isHuman } = require("%rGui/hudUnitType.nut")
let { eventbus_subscribe } = require("eventbus")


let { activeOrderComps }= require("%rGui/activeOrder.nut")
let voiceChat = require("%rGui/chat/voiceChat.nut")
let hudLogs = require("%rGui/hudLogs.nut")

let leftPanelGap = hdpxi(20)
let smallPadding = hdpxi(4)
let bigPadding = hdpxi(12)


let isMapSpectatorVisible = Watched(true)
let rightPanelOffset = Computed(@()
  !isSpectatorMode.get() || !isMapSpectatorVisible.get() ? 0
    : (tacticalMapStates.get()?.size[0] ?? 0) + bigPadding)

eventbus_subscribe("updateSpectatorMapStates",
  @(v) isMapSpectatorVisible.set(v?.isVisible ?? false))


let centerPanel = {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  size = flex()
  children = hitMarks
}


let dominationText = Computed(function() {
  if (totalDomTeam.get() == 0)
    return null
  let mult = totalDomMult.get()
  if (totalDomNextMult.get() > 0) {
    let secLeft = totalDomSecLeft.get()
    return string.format("x%d > x%d  %02d:%02d", mult, totalDomNextMult.get(), secLeft / 60, secLeft % 60)
  }
  return $"DOM x{mult}"
})

let dominationColor = Computed(@() totalDomTeam.get() == localTeam.get()
  ? teamColors.get().teamScoreBlueColor
  : teamColors.get().teamScoreRedColor)

let dominationTimer = @() {
  watch = [dominationText, dominationColor]
  vplace = ALIGN_TOP
  hplace = ALIGN_CENTER
  pos = [0, hdpx(86)] 
  children = dominationText.get() == null ? null : {
    rendObj = ROBJ_TEXT
    font = Fonts.medium_text_hud
    color = dominationColor.get()
    text = dominationText.get()
  }
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

let rightPanel = @() {
  watch = rightPanelOffset
  margin = [0,rightPanelOffset.get(),0,0]
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
    dominationTimer
  ]
}

return {
  infantryHudLeftPanel = leftPanel
  infantryHud
}