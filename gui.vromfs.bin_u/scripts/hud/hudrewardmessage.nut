from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import REWARD_PRIORITY

let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")

let g_hud_reward_message = {
  types = []

  cache = {
    byCode = {}
  }
}

g_hud_reward_message.getMessageByCode <- function getMessageByCode(code) {
  return enumsGetCachedType("code", code, this.cache.byCode,
    g_hud_reward_message, g_hud_reward_message.UNKNOWN)
}


g_hud_reward_message._getViewClass <- function _getViewClass(rewardValue) {
  return rewardValue >= 0 ? this.viewClass : "penalty"
}

g_hud_reward_message._getText <- function _getText(rewardValue, counter, expClass, messageModifier) {
  local result = loc(this.locFn(expClass, messageModifier))
  if (rewardValue < 0)
    result = "".concat(result, loc("warpoints/friendly_fire_penalty"))

  if (counter > 1)
    result = "".concat(loc("warpoints/counter", { counter = counter }), result)

  return result
}

g_hud_reward_message.template <- {
  code = -1
  locId = ""
  locFn = @(_expClass, _messageModifier) this.locId
  viewClass = ""
  priority = REWARD_PRIORITY.common 

  getViewClass = g_hud_reward_message._getViewClass
  getText = g_hud_reward_message._getText
}

enumsAddTypes(g_hud_reward_message, {
  UNKNOWN = {}

  LANDING = {
    code = EXP_EVENT_LANDING
    locId = "exp_reasons/landing"
  }

  TAKEOFF = {
    code = EXP_EVENT_TAKEOFF
    locId = "exp_reasons/takeoff"
  }

  CAPTURE_ZONE = {
    code = EXP_EVENT_CAPTURE_ZONE
    locId = "exp_reasons/capture"
    viewClass = "kill"
    priority = REWARD_PRIORITY.hit
  }

  DESTROY_ZONE = {
    code = EXP_EVENT_DESTROY_ZONE
    locId = "exp_reasons/destroy"
    viewClass = "kill"
    priority = REWARD_PRIORITY.hit
  }

  SIGHT = {
    code = EXP_EVENT_SIGHT
    locId = "exp_reasons/sight"
    priority = REWARD_PRIORITY.hit
  }

  KILL = {
    code = EXP_EVENT_KILL
    locId = "exp_reasons/kill"
    locFn = function (expClass, messageModifier) {
      local locId = (expClass == "exp_helicopter") ? "exp_reasons/kill_helicopter" : "exp_reasons/kill"
      if (["finishing_other", "from_severe_damage"].contains(messageModifier))
        locId = $"{locId}_{messageModifier}"
      return locId
    }

    viewClass = "kill"
    priority = REWARD_PRIORITY.kill
  }

  KILL_BY_TEAM = {
    code = EXP_EVENT_KILL_BY_TEAM
    locId = "exp_reasons/kill_by_team"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  KILL_GROUND = {
    code = EXP_EVENT_KILL_GROUND
    locId = "exp_reasons/kill_gm"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  ROUND_AWARD = {
    code = EXP_EVENT_ROUND_AWARD
  }

  SESSION_AWARD = {
    code = EXP_EVENT_SESSION_AWARD
  }

  BATTLETIME = {
    code = EXP_EVENT_BATTLETIME
  }

  STREAK = {
    code = EXP_EVENT_STREAK
  }

  CRITICAL_HIT = {
    code = EXP_EVENT_CRITICAL_HIT
    locId  = "exp_reasons/critical_hit"
    viewClass = "critical_hit"
    priority = REWARD_PRIORITY.critical
  }

  HIT = {
    code = EXP_EVENT_HIT
    locId  = "exp_reasons/hit"
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  ASSIST = {
    code = EXP_EVENT_ASSIST
    locId  = "exp_reasons/assist"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  DAMAGE_ZONE = {
    code = EXP_EVENT_DAMAGE_ZONE
    locId  = "exp_reasons/damage_zone"
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  OVERKILL = {
    code = EXP_EVENT_OVERKILL
    locId  = "exp_reasons/overkill"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  BATTLETROPHY = {
    code = EXP_EVENT_BATTLETROPHY
    locId  = "exp_reasons/battle_trophy"
    priority = REWARD_PRIORITY.assist
  }

  INEFFECTIVE_HIT = {
    code = EXP_EVENT_INEFFECTIVE_HIT
    locId  = "exp_reasons/ineffective_hit"
    priority = REWARD_PRIORITY.common
  }

  RESPAWN = {
    code = EXP_EVENT_RESPAWN
  }

  OBJECTIVE = {
    code = EXP_EVENT_OBJECTIVE
    locId  = "exp_reasons/objective"
    viewClass = "kill"
  }

  RACE_FINISHED = {
    code = EXP_EVENT_RACE_FINISHED
    viewClass = "kill"
    priority = REWARD_PRIORITY.kill
  }

  UNIT_DAMAGE = {
    code = EXP_EVENT_UNIT_DAMAGE
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  SCOUT = {
    code = EXP_EVENT_SCOUT
    locId  = "exp_reasons/scout"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout
  }

  SCOUT_CRITICAL_HIT = {
    code = EXP_EVENT_SCOUT_CRITICAL_HIT
    locId  = "exp_reasons/scout_critical_hit"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout_hit
  }

  SCOUT_KILL = {
    code = EXP_EVENT_SCOUT_KILL
    locId  = "exp_reasons/scout_kill"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout_kill
  }

  SCOUT_KILL_UNKNOWN = {
    code = EXP_EVENT_SCOUT_KILL_UNKNOWN
    locId  = "exp_reasons/scout_kill_unknown"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout_kill_unknown
  }

  TIMED_AWARD = {
    code = EXP_EVENT_TIMED_AWARD
    locId  = "exp_reasons/timed_award"
    viewClass = "kill"
    priority = REWARD_PRIORITY.timed_award
  }

  SEVERE_DAMAGE = {
    code = EXP_EVENT_SEVERE_DAMAGE
    locId  = "exp_reasons/severe_damage"
    viewClass = "critical_hit"
    priority = REWARD_PRIORITY.severe
  }

  MISSILE_EVADE = {
    code = EXP_EVENT_MISSILE_EVADE
    locId  = "exp_reasons/missile_evade"
    priority = REWARD_PRIORITY.hit
  }

  SHELL_INTERCEPTION = {
    code = EXP_EVENT_SHELL_INTERCEPTION
    locId  = "exp_reasons/shell_interception"
    priority = REWARD_PRIORITY.hit
  }

  RETURN_SPAWN_COST = {
    code = EXP_EVENT_RETURN_SPAWN_COST
    locFn = function (_expClass, messageModifier) {
      local locId = "exp_reasons/return_spawn_cost"
      if (messageModifier != "")
        locId = $"{locId}/{messageModifier}"
      return locId
    }
    priority = REWARD_PRIORITY.kill
  }

})

return {
  g_hud_reward_message
}