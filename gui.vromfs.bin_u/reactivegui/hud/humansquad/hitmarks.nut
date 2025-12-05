from "%rGui/globals/ui_library.nut" import *
from "%sqstd/underscore.nut" import partition
import "%sqstd/ecs.nut" as ecs

let { Projection } = require("wt.behaviors")

let { hitMarks, hitMarkEid } = require("%rGui/hud/state/hit_marks_es.nut")
let { mkColoredGradientX } = require("%rGui/style/gradients.nut")
let { register_command } = require("console")


const ANIM_TRIGGER_HIT      = "hero_make_hit_anim"
const ANIM_TRIGGER_KILL     = "hero_make_kill_anim"
const ANIM_TRIGGER_HEADSHOT = "hero_make_headshot_anim"
const ANIM_TRIGGER_ARMOR    = "hero_make_armor_hit_anim"


let hitColor = 0xFFFFFFFF
let killColor = 0xFFED0905
let armorColor = 0xCC95B3D7


let blockWidth = evenPx(108)
let freeLineWidth = evenPx(44)
let hitmarkLineWidth = evenPx(28)
let killmarkLineWidth = evenPx(38)
let armorLineWidth = evenPx(16)
let hitmarkLineHeight = evenPx(2)
let hitmarkHitShift = evenPx(16)


let gradientLineHit = mkColoredGradientX(0x00000000, hitColor, hitmarkLineWidth)
let gradientLineKill = mkColoredGradientX(0x00000000, killColor, killmarkLineWidth)
let gradientLineArmor = mkColoredGradientX(armorColor, armorColor, armorLineWidth)


let animFadeOutSec = 0.01
let animFadeInSec = 0.1
let animHitShiftDuration = 0.075
let opacityOnShift = 0.7


let currentHitMark = Watched(null)


function isPositionalHitMark(v) {
  if (v?.hitPos==null)
    return false
  return v?.isMelee
}
function updateHitMarks(hitMarksRes) {
  let res = partition(hitMarksRes, isPositionalHitMark)
  let hitms = res[1]
  currentHitMark.set((hitms?.len() ?? 0)>0 ? hitms?[hitms.len()-1] : null)
}
hitMarks.subscribe(updateHitMarks)
updateHitMarks(hitMarks.get())

currentHitMark.subscribe(function(v) {
  if (v == null)
    return

  local playAnimId = ""

  if (v?.isArmorEffective)
    playAnimId = ANIM_TRIGGER_ARMOR
  else if ((v?.isCritical ?? false) && (v?.isKillHit))
    playAnimId = ANIM_TRIGGER_HEADSHOT
  else if (v?.isKillHit || v?.isDownedHit)
    playAnimId = ANIM_TRIGGER_KILL
  else
    playAnimId = ANIM_TRIGGER_HIT

  foreach (animId in [ANIM_TRIGGER_ARMOR, ANIM_TRIGGER_HEADSHOT,
                      ANIM_TRIGGER_KILL, ANIM_TRIGGER_HIT])
    if (animId != playAnimId)
      anim_skip(animId)

  anim_start(playAnimId)
})


let mkImg = @(image, rotate, trigger, lineWidth) {
  rendObj = ROBJ_IMAGE
  image
  size = [lineWidth , hitmarkLineHeight]
  transform = { rotate }
  pos = [ rotate == 0 ? -freeLineWidth : freeLineWidth , 0]
  opacity = 0
  animations = [
    {
      prop = AnimProp.opacity, from = 0, to = 1, duration = animFadeOutSec, trigger
    }
    {
      prop = AnimProp.translate, to = [ rotate == 0 ? hitmarkHitShift : -hitmarkHitShift, 0 ],
      duration = animHitShiftDuration, easing = Linear, delay = animFadeOutSec, trigger,
      playFadeOut = true
    }
    {
      prop = AnimProp.opacity, from = 1, to = opacityOnShift, duration = animHitShiftDuration,
      delay = animFadeOutSec, trigger
    }
    {
      prop = AnimProp.opacity, from = opacityOnShift, to = 0, duration = animFadeInSec,
      delay = animHitShiftDuration + animFadeOutSec, trigger
    }
  ]
}


let mkImgArmor = @(image, rotate, trigger) {
  rendObj = ROBJ_IMAGE
  image
  size = [armorLineWidth , hitmarkLineHeight]
  transform = { rotate }
  pos = [ rotate == 0 ? -freeLineWidth : freeLineWidth , 0]
  opacity = 0
  animations = [
    { prop=AnimProp.opacity, from=0.4, to=1, duration=0.2, trigger }
  ]
}

let lineLeft = mkImg(gradientLineHit, 0, ANIM_TRIGGER_HIT, hitmarkLineWidth)
let lineRight = mkImg(gradientLineHit, 180, ANIM_TRIGGER_HIT, hitmarkLineWidth)
let lineKillLeft = mkImg(gradientLineKill, 0, ANIM_TRIGGER_KILL, killmarkLineWidth)
let lineKillRight = mkImg(gradientLineKill, 180, ANIM_TRIGGER_KILL, killmarkLineWidth)
let lineHeadshotLeft = mkImg(gradientLineKill, 0, ANIM_TRIGGER_HEADSHOT, killmarkLineWidth)
let lineHeadshotRight = mkImg(gradientLineKill, 180, ANIM_TRIGGER_HEADSHOT, killmarkLineWidth)
let lineArmorLeft = mkImgArmor(gradientLineArmor, 0, ANIM_TRIGGER_ARMOR)
let lineArmorRight = mkImgArmor(gradientLineArmor, 180, ANIM_TRIGGER_ARMOR)


let hitMarkNormal = {
  size = [ blockWidth, blockWidth ]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  transform = { rotate = 45 }
  children = [
    lineLeft
    lineRight
    {
      size = flex()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        lineLeft
        lineRight
      ]
      transform = { rotate = 90 }
    }
  ]
}

let hitMarKill = {
  size = [ blockWidth, blockWidth ]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  transform = { rotate = 45 }
  children = [
    lineKillLeft
    lineKillRight
    {
      size = flex()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        lineKillLeft
        lineKillRight
      ]
      transform = { rotate = 90 }
    }
  ]
}

let lineHeadshotLeftBlock = {
  flow = FLOW_VERTICAL
  gap = hitmarkLineHeight
  children = [
    lineHeadshotLeft
    lineHeadshotLeft
  ]
}
let lineHeadshotRightBlock = {
    flow = FLOW_VERTICAL
    gap = hitmarkLineHeight
    children = [
      lineHeadshotRight
      lineHeadshotRight
    ]
  }

let hitMarkHeadshot = {
  size = [ blockWidth, blockWidth ]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  transform = { rotate = 45 }
  children = [
    lineHeadshotLeftBlock
    lineHeadshotRightBlock
    {
      size = flex()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        lineHeadshotLeftBlock
        lineHeadshotRightBlock
      ]
      transform = { rotate = 90 }
    }
  ]
}

let hitMarkArmor = {
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  transform = { rotate = 45 }
  children = [
    lineArmorLeft
    lineArmorRight
    {
      size = flex()
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        lineArmorLeft
        lineArmorRight
      ]
      transform = { rotate = 90 }
    }
  ]
}

function mkHitMarks() {
  return {
    watch = hitMarkEid
    behavior = hitMarkEid.get() == ecs.INVALID_ENTITY_ID ? null : Projection
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = {
      data = {
        eid = hitMarkEid.get()
      }
      transform = hitMarkEid.get() == ecs.INVALID_ENTITY_ID ? null : {}
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      children = [
        hitMarkNormal
        hitMarKill
        hitMarkHeadshot
        hitMarkArmor
      ]
    }
  }
}


register_command(@() anim_start(ANIM_TRIGGER_HIT), "ui.debug.play_anim_hit")
register_command(@() anim_start(ANIM_TRIGGER_KILL), "ui.debug.play_anim_kill")
register_command(@() anim_start(ANIM_TRIGGER_HEADSHOT), "ui.debug.play_anim_headshot")
register_command(@() anim_start(ANIM_TRIGGER_ARMOR), "ui.debug.play_anim_armor_hit")


return {
  hitMarks = mkHitMarks
}