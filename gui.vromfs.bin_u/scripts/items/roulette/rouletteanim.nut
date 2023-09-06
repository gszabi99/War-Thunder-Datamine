//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { frnd } = require("dagor.random")

let enums = require("%sqStdLibs/helpers/enums.nut")
let { lerp, fabs } = require("%sqstd/math.nut")
let cubicBezierSolver = require("%globalScripts/cubicBezierSolver.nut")
let { parse_json } = require("json")

let CHANCE_TO_STOP_ON_BORDER = 0.5

enum ANIM_ACTION {
  START
  SKIP
}

let rouletteAnim = {
  types = []
}

rouletteAnim.template <- {
  id = "" //filled automatically by typeName. so unique
  skipAnimTime = 0.5

  startAnim = @(obj, targetIdx) obj.setValue(::save_to_json(
    { action = ANIM_ACTION.START, animId = this.id, targetIdx = targetIdx }))
  skipAnim  = @(obj) obj.setValue(::save_to_json(
    { action = ANIM_ACTION.SKIP }))

  makeBhvAnimConfig = @() {
    anim = this
    time = 0.0
    timeToStopSound = 0.5
    totalTime = 1.0
    isJustStarted = true
    animFunc = @(_time) 0
  }

  calcAnimConfig = function(obj, params) {
    let targetIdx = params.targetIdx
    if (targetIdx < 0 || targetIdx >= obj.childrenCount())
      return null
    let itemWidth = to_pixels("@itemWidth")
    let targetWidth = obj.getChild(targetIdx).getSize()[0]
    let targetPos = (-obj.getChild(targetIdx).getPos()[0] - 0.5 * targetWidth
      + obj.getPos()[0] + 0.5 * obj.getParent().getSize()[0] / 2).tofloat()
    return this.calcAnimConfigImpl(targetPos, targetWidth, itemWidth)
  }

  calcAnimConfigImpl = @(targetPos, _targetWidth, _itemWidth)
    this.makeBhvAnimConfig().__update({
      animFunc = @(_time) targetPos
    })

  calcSkipAnimConfig = function(curConfig) {
    if (curConfig.time >= curConfig.totalTime)
      return null //do nothing

    let pos1 = curConfig.animFunc(curConfig.time)
    let pos2 = curConfig.animFunc(curConfig.totalTime)
    if (fabs(pos2 - pos1) < 1)
      return null

    let time = this.skipAnimTime
    let a = (pos1 - pos2) / (2 * time * time)
    let b = -2 * a * time
    let c = pos1
    return this.makeBhvAnimConfig().__update({
      isJustStarted = false
      timeToStopSound = 0.01
      totalTime = time
      animFunc = @(t) (t >= time) ? pos2 : a * t * t + b * t + c
    })
  }

  //Returns random displacement in segment [-1.0, 1.0]
  //with a higher chance to be closer to the border
  getRandomEndDisplacement = function() {
    let sign = frnd() > 0.5 ? 1.0 : -1.0
    if (frnd() <= CHANCE_TO_STOP_ON_BORDER)
      return sign

    let mean = frnd()
    // Chance of further displacement is higher.
    return sign * (1.0 - mean * mean)
  }
}

enums.addTypes(rouletteAnim, {
  DEFAULT = {
    MIN_TIME = 5.75
    MAX_TIME = 6.75
    FINAL_ANIM_TIME = 0.5

    function calcAnimConfigImpl(targetPos, targetWidth, _itemWidth) {
      let time1 = lerp(0.0, 1.0, this.MIN_TIME, this.MAX_TIME, frnd())
      let time2 = time1 + this.FINAL_ANIM_TIME
      let pos1 = targetPos + this.getRandomEndDisplacement() * 0.5 * targetWidth
      let pos2 = targetPos

      let animFunc = (@(t) (t < time1) ? pos1 * cubicBezierSolver.solve(t / time1, 0.16, 0, 0.0, 1.0)
        : (t < time2) ? pos1 + (pos2 - pos1) * cubicBezierSolver.solve((t - time1) / this.FINAL_ANIM_TIME, 0.55, 0, 0.32, 1.42)
        : targetPos
      ).bindenv(this)

      return this.makeBhvAnimConfig().__update({
        timeToStopSound = time1
        totalTime = time2
        animFunc = animFunc
      })
    }
  }

  LONG = {
    TIME_TO_MAX_SPEED = 1.0
    TIME_TO_SLOW_SPEED = 6.0
    TIME_TO_FINALIZE = 0.5 //time to move from final point to item center

    SLOW_SPEED = 1 //speed for N last items before choose. (items per sec)
    MIN_ITEMS_SLOW_SPEED = 3
    MAX_ITEMS_SLOW_SPEED = 7

    getTimeAtSlowSpeed = @(itemsAmount) 2.0 * this.SLOW_SPEED * itemsAmount

    function calcAnimConfigImpl(targetPos, targetWidth, itemWidth) {
      //from 0 t o t1: s = a1 * t * t                 //fast speed up roulette
      //from t1 to t2: s = a2 * t * t + b2 * t + c2   //speed slower until reach SLOW_SPEED
      //from t2 to t3: s = a3 * t * t + b3 * t + c3   //move at slow speed
      //from t3 to t4: s = a4 * t * t + b4 * t + c4   //fallback to current item center

      //initialize known constants
      let v2 = -this.SLOW_SPEED.tofloat() * itemWidth
      let t1 = this.TIME_TO_MAX_SPEED.tofloat()
      let t2 = this.TIME_TO_SLOW_SPEED.tofloat()

      //calc distances (except first one which depend on many params
      //all distances are negative
      let s4 = targetPos
      let displacement = this.getRandomEndDisplacement()
      let s3 = s4 + displacement * 0.5 * targetWidth
      let slowSpeedItems = this.getItemsAmountWithSlowSpeed()
      let s2 = s3 + itemWidth * slowSpeedItems
      if (s4 >= 0 || s2 >= 0) {
        ::script_net_assert_once("failed to calc position", "rouletteAnim: Failed to get target pos")
        return null
      }

      //calc 2nd part params
      let b2 = (2.0 * s2 - v2 * t2) / (t2 - t1)
      let a2 = (v2 - b2) / (2 * t2)
      let c2 = s2 - a2 * t2 * t2 - b2 * t2

      //calc 1stpart params
      let v1 = t1 * v2 / t2 + b2 * (1 - t1 / t2)
      let a1 = v1 / (2 * t1)

      //calc 3rd part params
      let slowTime = this.getTimeAtSlowSpeed(slowSpeedItems)
      let t3 = t2 + slowTime
      let a3 = (s2 - s3) / (slowTime * slowTime)
      let b3 = -2 * a3 * t3
      let c3 = s2 - a3 * t2 * t2 - b3 * t2

      //calc 4th part params
      let t4 = t3 + this.TIME_TO_FINALIZE
      let a4 = (s3 - s4) / (this.TIME_TO_FINALIZE * this.TIME_TO_FINALIZE)
      let b4 = -2 * a4 * t4
      let c4 = s4 - a4 * t4 * t4 - b4 * t4

      let animFunc = @(t) (t < t1) ? a1 * t * t
        : (t < t2) ? a2 * t * t + b2 * t + c2
        : (t < t3) ? a3 * t * t + b3 * t + c3
        : (t < t4) ? a4 * t * t + b4 * t + c4
        : s4

      return this.makeBhvAnimConfig().__update({
        timeToStopSound = t3
        totalTime = t4
        animFunc = animFunc
      })
    }

    //return fractional amount of items required to move with the SLOW_SPEED.
    getItemsAmountWithSlowSpeed = @()
      this.MIN_ITEMS_SLOW_SPEED.tofloat() + frnd() * (this.MAX_ITEMS_SLOW_SPEED - this.MIN_ITEMS_SLOW_SPEED)
  }
},
null, "id")

rouletteAnim.calcAnimConfig <- function(obj, value, curConfig) {
  let params = parse_json(value)
  if (params?.action == null)
    return null
  if (params.action == ANIM_ACTION.SKIP)
    return curConfig ? curConfig.anim.calcSkipAnimConfig(curConfig) : null
  if (params.action == ANIM_ACTION.START) {
    let anim = this?[params.animId] ?? this.DEFAULT
    return anim.calcAnimConfig(obj, params)
  }
  return null
}

rouletteAnim.getTimeLeft <- function(obj) {
  //return time to finalize animation
  let config = obj.getUserData()
  return config ? config.totalTime - config.time : 0
}

rouletteAnim.get <- @(id) this?[id.toupper()] ?? this.DEFAULT

return rouletteAnim