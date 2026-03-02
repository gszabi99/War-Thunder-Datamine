from "%rGui/globals/ui_library.nut" import *

let { hudLogBgColor } = require("%rGui/style/colors.nut").hud
let { totalCrewMembersCount, aliveCrewMembersCount, minCrewMembersCount } = require("%rGui/crewState.nut")
let { resetTimeout } = require("dagor.workcycle")
let { damageIndicatorScale } = require("%rGui/options/options.nut")

const badCrewTextColor = 0xFFc56e18
const goodCrewTextColor = 0xC8C8C8C8
const crewIconSize = hdpxi(40)
let aliveBarTargetPercent = Watched(1)
let aliveBarStartPercent = Watched(1)

const flashBarDuration = 0.5
const lostBarDuration = 0.5
const lifeBarHeight = shHud(1.2)

let lostCrewCount = Watched(0)
const lostBarAnimTrigger = {}
const lostCountTextTrigger = {}

local lastCrewAliveCount = -1
local canAddingLostCrewCounts = false

let lifePercent = keepref(Computed(@() totalCrewMembersCount.get() > 0
  ? aliveCrewMembersCount.get() / totalCrewMembersCount.get().tofloat()
  : 1
))

let crewFontSize = Computed(@() damageIndicatorScale.get() < 1 ? getFontDefHt("tiny_text_hud") * damageIndicatorScale.get() : null)
let crewTextColor = Computed(@() aliveCrewMembersCount.get() > minCrewMembersCount.get() ? goodCrewTextColor : badCrewTextColor)

function onCanAddingLostTimer() {
  canAddingLostCrewCounts = false
}

function onChangeLifePercent(val) {
  aliveBarStartPercent.set(aliveBarTargetPercent.get())
  aliveBarTargetPercent.set(clamp(val, 0, 1))

  let alive = aliveCrewMembersCount.get()
  let lastAlive = lastCrewAliveCount == -1 ? totalCrewMembersCount.get() : lastCrewAliveCount
  lastCrewAliveCount = alive

  if (alive >= lastAlive || alive == totalCrewMembersCount.get())
    return

  let lostCount = alive - lastAlive
  if (canAddingLostCrewCounts)
    lostCrewCount.set(lostCrewCount.get() + lostCount)
  else
    lostCrewCount.set(lostCount)

  canAddingLostCrewCounts = true
  resetTimeout(flashBarDuration + lostBarDuration, onCanAddingLostTimer)
  anim_start(lostCountTextTrigger)
  anim_start(lostBarAnimTrigger)
}

lifePercent.subscribe(onChangeLifePercent)

let lifebarBg = {
  size = [pw(100), ph(100)]
  rendObj = ROBJ_BOX
  fillColor = 0x1c1c1c
}

let aliveBar = @() {
  watch = aliveBarTargetPercent
  size = [pw(aliveBarTargetPercent.get() * 100) , ph(100)]
  rendObj = ROBJ_BOX
  fillColor = 0xffc0c0c0
}

let flashBar = @() {
  watch = [aliveBarTargetPercent, aliveBarStartPercent]
  pos = [pw(aliveBarTargetPercent.get() * 100), 0]
  size = [pw((aliveBarStartPercent.get() - aliveBarTargetPercent.get()) * 100) , ph(100)]
  rendObj = ROBJ_BOX
  fillColor = 0xFFFF0000
  opacity = 0
  animations = [
    {
      prop = AnimProp.opacity
      from = 1
      to = 0
      duration = flashBarDuration
      easing = InOutCubic
      trigger = lostBarAnimTrigger
    }
  ]
}

let lostBar = @() {
  watch = [aliveBarTargetPercent, aliveBarStartPercent]
  pos = [pw(aliveBarTargetPercent.get() * 100), 0]
  size = [pw((aliveBarStartPercent.get() - aliveBarTargetPercent.get()) * 100) , ph(100)]
  rendObj = ROBJ_BOX
  fillColor = badCrewTextColor
  transform = {pivot = [0, 0.5], scale = [0, 1]}
  animations = [
    {
      prop = AnimProp.scale
      from = [1, 1]
      to = [1, 1]
      duration = flashBarDuration
      easing = Linear
      trigger = lostBarAnimTrigger
    },
    {
      prop = AnimProp.scale
      from = [1, 1]
      to = [0, 1]
      duration = lostBarDuration
      delay = flashBarDuration
      easing = Linear
      trigger = lostBarAnimTrigger
    }
  ]
}

let crewLostText = @() {
  watch = [lostCrewCount, crewFontSize]
  rendObj = ROBJ_TEXT
  text = $"{lostCrewCount.get()}"
  color = badCrewTextColor
  opacity = 0
  fontSize = crewFontSize.get()
  animations = [
    {
      prop = AnimProp.opacity
      from = 1
      to = 0
      duration = flashBarDuration + lostBarDuration + 0.5
      easing = InOutSine
      trigger = lostCountTextTrigger
    }
  ]
}

let minAliveBar = @() {
  watch = [minCrewMembersCount, totalCrewMembersCount]
  size = [
    pw(100 * (totalCrewMembersCount.get() == 0
      ? 0
      : minCrewMembersCount.get() / totalCrewMembersCount.get().tofloat())
    ),
    ph(100)
  ]
  rendObj = ROBJ_BOX
  fillColor = 0xFF7c7f84
}

let crewLifebar = {
  size = [pw(100), lifeBarHeight]
  padding = hdpx(3)
  rendObj = ROBJ_BOX
  borderColor = 0x46464646
  borderWidth = hdpx(1)
  children = [
    lifebarBg
    lostBar
    flashBar
    aliveBar
    minAliveBar
  ]
}

let crewsCountPanel = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(3)
  children = [
    {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      gap = hdpx(3)
      children = [
        @() {
          watch = [totalCrewMembersCount, aliveCrewMembersCount, crewTextColor, crewFontSize]
          rendObj = ROBJ_TEXT
          fontSize = crewFontSize.get()
          color = crewTextColor.get()
          text = $"{loc("crew/totalCrew")}: {aliveCrewMembersCount.get()}/{totalCrewMembersCount.get()}"
        }
        crewLostText
      ]
    }
    crewLifebar
  ]
}

let panelContent = {
  flow = FLOW_HORIZONTAL
  size = [pw(100), SIZE_TO_CONTENT]
  gap = { size = const [hdpx(5), hdpx(5)] }
  padding = const [hdpx(5), hdpx(10)]
  valign = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = hudLogBgColor

  children = [
    @() {
      watch = crewTextColor
      rendObj = ROBJ_IMAGE
      size = crewIconSize
      color = crewTextColor.get()
      image = Picture($"ui/gameuiskin#ship_crew.svg:{crewIconSize}:{crewIconSize}:P")
    }
    crewsCountPanel
  ]
}

return {
  crewLifebar = panelContent
}