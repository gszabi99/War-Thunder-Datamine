from "%rGui/globals/ui_library.nut" import *
import "%sqstd/ecs.nut" as ecs;

let { EventPickUpLoot, EventOnUnitDead  } = require("dasevents")
let { showMessage, toastMessagesComp } = require("%rGui/hud/toastMessages.nut")
let { timeLeft } = require("%rGui/missionState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let { mkBitmapPictureLazy } = require("%darg/helpers/bitmap.nut")
let { gradTexSize, mkGradientCtorRadial } = require("%rGui/style/gradients.nut")
let { isInFlight } = require("%rGui/globalState.nut")

const FONT_COLOR_ACCENT = 0xFFDBA94A
const FONT_COLOR_NEUTRAL = 0xFFFCFBE0
let font = Fonts.very_tiny_text_hud

const LOOT_ELECTRONICS_COLOR = 0xFFA6CD74
const LOOT_VEHICLE_PARTS_COLOR = 0xFFFE757D
const LOOT_ARMOR_COLOR = 0xFF74b5D5
const LOOT_SCRAP_COLOR = 0xFFE2924B

let PROGRESS_BAR_WIDTH = hdpxi(229)
let PROGRESS_BAR_HEIGHT = hdpxi(16)
let PROGRESS_BAR_BORDER_WIDTH = hdpx(3)

let SKULL_ICON_WIDTH = hdpxi(20)
let SKULL_ICON_HEIGHT = hdpxi(26)
let SKULL_CIRCLE_SIZE = hdpxi(42)

const SKULL_ICON_COLOR = 0xFFFCFBE0
const FULL_FURY_COLOR = 0xFFE56169

let HUD_MODAL_MIN_WIDTH = hdpxi(300)
let HUD_MODAL_HEIGHT = hdpxi(60)

let FIRE_ICON_WIDTH = hdpx(26)
let FIRE_ICON_HEIGHT = hdpx(46)

const FURY_PROGRESS_INACTIVE_COLOR = 0xFF474645
const FURY_COMPLETE_ANIM_DURATION = 1.0
const SKULL_FURY_ANIM_TRIGGER = "skull_fury"
let FURY_COMPLETE_ANIM_EASING = InOutQuad

let Rage = Watched(0)
let lootState = {
  Capacity = Watched(0)
  CurLoad = Watched(0)
  ScrapCnt = Watched(0)
  PartsCnt = Watched(0)
  ArmorCnt = Watched(0)
  ElectricCnt = Watched(0)
  Rage
}

function clearState() {
  foreach (w in lootState)
    w.set(0)
}

enum LootType {
  SCRAP = 0,
  VEHICLE_PARTS = 1,
  ARMOR = 2,
  ELECTRONICS = 3
}

let lootTypes = {
  [LootType.SCRAP] = {
    loc = "mad_thunder_event/scrap/plural"
    color = LOOT_SCRAP_COLOR
    countW = lootState.ScrapCnt
  },
  [LootType.VEHICLE_PARTS] = {
    loc = "mad_thunder_event/vehicle_part/plural"
    color = LOOT_VEHICLE_PARTS_COLOR
    countW = lootState.PartsCnt
  },
  [LootType.ARMOR] = {
    loc = "mad_thunder_event/armor/plural"
    color = LOOT_ARMOR_COLOR
    countW = lootState.ArmorCnt
  },
  [LootType.ELECTRONICS] = {
    loc = "mad_thunder_event/electronics/plural"
    color = LOOT_ELECTRONICS_COLOR
    countW = lootState.ElectricCnt
  }
}

ecs.register_es("loot_pick_uped_es",
  {
    [["onInit", "onChange"]] = function updateLootState(_, comp) {
      let types = comp.loot_carrier__loot_type.getAll()
      let counts = comp.loot_carrier__loot_count.getAll()
      let rage = comp.loot_carrier__rage
      let rageDiff = rage - lootState.Rage.get()

      if (rageDiff > 0)
        showMessage([
          { text = $"+{rageDiff} ", ovr = { color = FULL_FURY_COLOR } }
          { text = loc("mad_thunder_event/fury/plural", { num = rageDiff }) }
        ])

      foreach(idx, t in types)
        lootTypes[t].countW.set(counts[idx])
      lootState.Capacity.set(comp.loot_carrier__capacity)
      lootState.Rage.set(rage)
      lootState.CurLoad.set(counts.reduce(@(total, c) total + c, 0))
    },

    [EventOnUnitDead] = clearState,

    [EventPickUpLoot] = function(e,_eid,_comp) {
      let msg = lootTypes?[e.loot_type]
      if (!msg)
        return
      showMessage([
        { text = $"+{e.count} ", ovr = { color = msg.color} }
        { text = loc(msg.loc, {num = e.count}) }
      ])
    }
  },
  {
    comps_track = [
      ["loot_carrier__loot_count", ecs.TYPE_INT_LIST],
      ["loot_carrier__loot_type", ecs.TYPE_INT_LIST],
      ["loot_carrier__rage", ecs.TYPE_INT],
      ["loot_carrier__capacity", ecs.TYPE_INT]
    ],
    comps_rq = ["controlledHero"]
  }
)

let lootItemProgressBars = [
  lootTypes[LootType.ELECTRONICS]
  lootTypes[LootType.VEHICLE_PARTS]
  lootTypes[LootType.ARMOR]
  lootTypes[LootType.SCRAP]
]


let mkLootItemProgressBar = @(countW, fillColor) @() {
  watch = [countW, lootState.Capacity]
  size = [
    (lootState.Capacity.get() == 0) ? 0 : pw(countW.get() * 100 / lootState.Capacity.get())
    flex()
  ]
  rendObj = ROBJ_BOX
  fillColor
  opacity = 1
}

let knownLootScaleSizes = [25, 50, 75, 100]
let getLootScaleSize = @(capacityV) knownLootScaleSizes.contains(capacityV)
  ? capacityV
  : knownLootScaleSizes[0]

let lootProgressBarComp = {
  children = [
    {
      size = [PROGRESS_BAR_WIDTH, PROGRESS_BAR_HEIGHT]
      padding = PROGRESS_BAR_BORDER_WIDTH
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#StrokeFill.svg:{PROGRESS_BAR_WIDTH}:{PROGRESS_BAR_HEIGHT}:P")
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = lootItemProgressBars.map(@(bar) mkLootItemProgressBar(bar.countW, bar.color))
    }
    {
      size = [PROGRESS_BAR_WIDTH, PROGRESS_BAR_HEIGHT]
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#texture_fill.avif:{PROGRESS_BAR_WIDTH}:{PROGRESS_BAR_HEIGHT}:P")
    }
    @() {
      watch = lootState.Capacity
      pos = [hdpx(3), hdpx(2)]
      size = [hdpx(223), hdpx(11)]
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#loot_scale_{getLootScaleSize(lootState.Capacity.get())}.svg:{hdpx(223)}:{hdpx(11)}:P")
    }
  ]
}

let lootProgressComp = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = hdpx(5)
  children = [
    @() {
      watch = lootState.CurLoad
      rendObj = ROBJ_TEXT
      font
      color = FONT_COLOR_NEUTRAL
      text = lootState.CurLoad.get()
    }
    lootProgressBarComp
    @() {
      watch = lootState.Capacity
      rendObj = ROBJ_TEXT
      font
      color = FONT_COLOR_NEUTRAL
      text = lootState.Capacity.get()
    }
  ]
}

let timeLeftComp =  @() {
  watch = timeLeft
  minWidth = hdpx(31)
  rendObj = ROBJ_TEXT
  font
  color = FONT_COLOR_NEUTRAL
  text = secondsToTimeSimpleString(timeLeft.get())
}

let missionGoalHeaderComp = @() {
  watch = [lootState.CurLoad, lootState.Capacity]
  rendObj = ROBJ_TEXT
  font
  color = FONT_COLOR_ACCENT
  text = lootState.CurLoad.get() == 0 || lootState.CurLoad.get() != lootState.Capacity.get()
    ? loc("mad_thunder_event/gather_the_material")
    : loc("mad_thunder_event/evacuate")
}

let furyProgressBars = [
  {
    pos = [hdpx(-24), hdpx(-3)]
    transform = { rotate = -81 }
  }
  {
    pos = [hdpx(-16), hdpx(-18)]
    transform = { rotate = -41 }
  }
  {
    pos = [hdpx(0), hdpx(-24)]
  }
  {
    pos = [hdpx(16), hdpx(-18)]
    transform = { rotate = 41 }
  }
  {
    pos = [hdpx(24), hdpx(-3)]
    transform = { rotate = 81 }
  }
]

let isFuryProgressCompleted = Computed(@() Rage.get() >= furyProgressBars.len())

let mkFireIcon = @(isLeft = false) @() {
  watch = isFuryProgressCompleted
  size = [FIRE_ICON_WIDTH, FIRE_ICON_HEIGHT]
  pos = [isLeft ? hdpx(-32) : hdpx(32), hdpx(-6)]
  rendObj = ROBJ_IMAGE
  color = FULL_FURY_COLOR
  image = Picture($"ui/gameuiskin#fire_fury_{isLeft ? "left" : "right"}.svg:{FIRE_ICON_WIDTH}:{FIRE_ICON_HEIGHT}:P")
  opacity = isFuryProgressCompleted.get() ? 1 : 0
  transform = isFuryProgressCompleted.get()
  ? {
      translate = [0, 0]
      rotate = 0
      scale = [1,1]
    }
  : {
      translate = [isLeft ? -50 : 50, 0]
      rotate = isLeft ? -45 : 45
      scale = [2,2]
    }
  transitions = [AnimProp.opacity, AnimProp.translate, AnimProp.rotate, AnimProp.scale].map(@(prop) {
    prop
    duration = FURY_COMPLETE_ANIM_DURATION
    easing = FURY_COMPLETE_ANIM_EASING
  })
}

let furyGlowAnimGrad =  mkBitmapPictureLazy(gradTexSize, gradTexSize,
  mkGradientCtorRadial(0XFFd17841, 0, gradTexSize / 3.5, gradTexSize / 4, gradTexSize / 2, gradTexSize / 2))

let furySkullGlowAnim = {
  key = {}
  size = [hdpx(54), hdpx(54)]
  rendObj = ROBJ_IMAGE
  image = furyGlowAnimGrad()
  opacity = 1
  animations = [
    { prop = AnimProp.scale, from = [1.5, 1.5], to = [1, 1], duration = 2, easing = InOutSine, play = true, loop = true }
    { prop = AnimProp.opacity, from = 1, to = 0.5, duration = 2, easing = InOutSine, play = true, loop = true }
  ]
}

let skullFuryIndicatorComp = @() {
  watch = isFuryProgressCompleted
  size = [SKULL_CIRCLE_SIZE, SKULL_CIRCLE_SIZE]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = [
    isFuryProgressCompleted.get() ? furySkullGlowAnim : null
    {
      size = [SKULL_CIRCLE_SIZE, SKULL_CIRCLE_SIZE]
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#elipse_fury.avif:{SKULL_CIRCLE_SIZE}:{SKULL_CIRCLE_SIZE}:P")
    }
    @() {
      watch = isFuryProgressCompleted
      size = [SKULL_ICON_WIDTH, SKULL_ICON_HEIGHT]
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#norm_skull.svg:{SKULL_ICON_WIDTH}:{SKULL_ICON_HEIGHT}:P")
      keepAspect = true
      color = isFuryProgressCompleted.get()
        ? FULL_FURY_COLOR
        : SKULL_ICON_COLOR
      transform = {}
      transitions = [
        {
          prop = AnimProp.color
          duration = FURY_COMPLETE_ANIM_DURATION
          easing = FURY_COMPLETE_ANIM_EASING
        }
      ]
      animations = [
        {
          prop = AnimProp.scale
          from = [1, 1]
          to = [1.2, 1.2]
          duration = FURY_COMPLETE_ANIM_DURATION / 2
          easing = FURY_COMPLETE_ANIM_EASING
          trigger = SKULL_FURY_ANIM_TRIGGER
        }
        {
          prop = AnimProp.scale
          from = [1.2, 1.2]
          to =[1,1]
          delay = FURY_COMPLETE_ANIM_DURATION / 2
          duration = FURY_COMPLETE_ANIM_DURATION / 2
          easing = FURY_COMPLETE_ANIM_EASING
          trigger = SKULL_FURY_ANIM_TRIGGER
        }
        {
          prop = AnimProp.rotate
          from = 0
          to =-15
          duration = FURY_COMPLETE_ANIM_DURATION / 2
          easing = FURY_COMPLETE_ANIM_EASING
          trigger = SKULL_FURY_ANIM_TRIGGER
        }
        {
          prop = AnimProp.rotate
          from = -15
          to = 0
          delay = FURY_COMPLETE_ANIM_DURATION / 2
          duration = FURY_COMPLETE_ANIM_DURATION / 2
          easing = FURY_COMPLETE_ANIM_EASING
          trigger = SKULL_FURY_ANIM_TRIGGER
        }
      ]
    }
    mkFireIcon(true)
    mkFireIcon()
  ].extend(furyProgressBars.map(@(bar, i) @() {
    watch = lootState.Rage
    size = [hdpx(14), hdpx(5)]
    rendObj = ROBJ_IMAGE
    image = Picture($"ui/gameuiskin#fury_progress_elem.svg:{hdpx(14)}:{hdpx(5)}:P")
    keepAspect = true
    color =  lootState.Rage.get() >= i + 1 ? 0xFFFFFFFF : FURY_PROGRESS_INACTIVE_COLOR
    transitions = [
      { prop = AnimProp.color, duratiuon = 0.2, easing = InOutQuad }
    ]
  }.__update(bar)))
}

let mainHudComp = {
  pos = [0, hdpx(27)]
  size = [SIZE_TO_CONTENT, HUD_MODAL_HEIGHT]
  minWidth = HUD_MODAL_MIN_WIDTH
  padding = [hdpx(17), hdpx(16), 0, hdpx(16)]
  rendObj = ROBJ_9RECT
  screenOffs = dp(2)+1
  texOffs = dp(2)+1
  image = Picture($"ui/gameuiskin#modal_bg.avif:{dp(300)}:{dp(60)}:P")
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = hdpx(2)
  children = [
    {
      flow = FLOW_HORIZONTAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      gap = hdpx(5)
      children = [
        timeLeftComp
        {
          size = [hdpx(1), hdpx(14)]
          rendObj = ROBJ_BOX
          fillColor = 0xFF7A6F61
        }
        missionGoalHeaderComp
      ]
    }
    lootProgressComp
  ]
}

let hud = {
  halign = ALIGN_CENTER
  children = [
    mainHudComp
    skullFuryIndicatorComp
  ]
}

isFuryProgressCompleted.subscribe(@(isCompleted) isCompleted && anim_start(SKULL_FURY_ANIM_TRIGGER))
isInFlight.subscribe(@(v) v ? clearState() : null)

return {
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = hdpx(28)
  children = [
    hud
    toastMessagesComp
  ]
}