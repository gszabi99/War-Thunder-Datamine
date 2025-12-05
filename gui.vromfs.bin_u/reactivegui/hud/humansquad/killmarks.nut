from "%rGui/globals/ui_library.nut" import *

let dagorMath = require("dagor.math")
let { killMarks } = require("%rGui/hud/state/hit_marks_es.nut")
let WTBhv = require("wt.behaviors")

let worldKillMarkSize = Watched([fsh(2.5),fsh(2.5)])
let worldKillMarkColor = 0xAAB41414
let worldDownedMarkColor = 0xAAE6781E

let mkAnimations = @() [
  { prop=AnimProp.opacity, from=0.2, to=1, duration=0.3, play=true, easing=InCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=2.7, delay = 0.3, play=true , easing=InCubic }
  {
    prop = AnimProp.translate,
    from=[0, 0], to=[0, -hdpx(3 * worldKillMarkSize.get()[1])],
    duration=3.0,
    play=true,
    easing=OutCubic
  }
  {
    prop = AnimProp.scale,
    from =[0.25, 0.25], to = [1, 1],
    duration = 0.3,
    easing = InCubic,
    play = true
  }
]

local killMarkImage
local downedMarkImage
function updateCache(...){
  killMarkImage = {
    size = worldKillMarkSize.get()
    rendObj = ROBJ_IMAGE
    color = worldKillMarkColor
    valign = ALIGN_CENTER
    transform = {}
    animations = mkAnimations()
    image = Picture("!ui/gameuiskin#heartbeat.svg:{0}:{1}:K"
      .subst(worldKillMarkSize.get()[0].tointeger(), worldKillMarkSize.get()[1].tointeger()))
  }
  downedMarkImage = killMarkImage.__merge({color=worldDownedMarkColor})
}

{
  [worldKillMarkSize]
    .map(@(v) v.subscribe(updateCache))
}
updateCache()

function mkKillMark(mark){
  let pos = mark.killPos
  return pos ? {
    data = {
      minDistance = 0.1
      clampToBorder = true
      worldPos = dagorMath.Point3(pos[0], pos[1], pos[2])
    }
    transform = {}
    children = mark.isKillHit ? killMarkImage : downedMarkImage
    key = mark?.id ?? {}
  } : null
}

function killMarksComp() {
  return {
    watch = [killMarks]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = const [sw(100), sh(100)]
    children = killMarks.get().map(mkKillMark)
    behavior = WTBhv.Projection
  }
}

return killMarksComp
