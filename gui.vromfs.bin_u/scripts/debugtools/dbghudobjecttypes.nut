from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_TYPE

let { g_hud_reward_message } = require("%scripts/hud/hudRewardMessage.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { rnd, frnd } = require("dagor.random")
let { HUD_MSG_DEATH_REASON } = require("hudMessages")
let { format } = require("string")
let { GO_FAIL, GO_WIN, MISSION_CAPTURING_ZONE, MISSION_CAPTURED_ZONE, MISSION_CAPTURING_STOP
} = require("guiMission")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { hud_message_objective_debug, hud_message_player_damage_debug, hud_message_kill_log_debug,
  hud_debug_streak
} = require("%scripts/debugTools/dbgHud.nut")

let getFakePlayer = @(id) {
  name = "somebodyName"
  clanTag = "<WWWWW>"
  isLocal = id == 1
  team = 2 - (id % 2)
  isInHeroSquad = (id % 4) == 1
}

let results = {
  types = []
  template = {
    eventChance = 100
    hudEventsList = null //array
    isVisible = function(_hudType) { return true }
    function genNewEvent() {
      if (!this.hudEventsList)
        return
      let hudEventData = u.chooseRandom(this.hudEventsList).map(@(val) u.isFunction(val) ? val() : val)
      g_hud_event_manager.onHudEvent(hudEventData.eventId, hudEventData)
    }
  }
}

enums.addTypes(results, {
  REWARD_MESSAGE = { //visible by prioriy
    eventChance = 50
    function genNewEvent() {
      let ignoreIdx = g_hud_reward_message.types.indexof(g_hud_reward_message.UNKNOWN)
      g_hud_event_manager.onHudEvent("InBattleReward", {
        messageCode = u.chooseRandomNoRepeat(g_hud_reward_message.types, ignoreIdx).code
        warpoints = 10 * (rnd() % 40)
        experience = 10 * (rnd() % 40)
        counter = 1
      })
    }
  }

  MISSION_COMPLETE = { //dosnt work in testflight
    eventChance = 20
    eventNames = ["MissionResult", "MissionContinue"]
    function genNewEvent() {
      g_hud_event_manager.onHudEvent(u.chooseRandom(this.eventNames), {
        resultNum = (rnd() % 2) ? GO_FAIL : GO_WIN
      })
    }
  }

  STREAK = {
    eventChance = 2
    genNewEvent = hud_debug_streak
  }

  MISSION_OBJECTIVE = {
    eventChance = 20
    genNewEvent = hud_message_objective_debug
  }

  KILL_LOG = {
    eventChance = 50
    genNewEvent = hud_message_kill_log_debug
  }

  PLAYER_DAMAGE = {
    eventChance = 50
    genNewEvent = hud_message_player_damage_debug
  }

  TANK_DEBUFFS_TIMERS = {
    eventChance = 100
    isVisible = function(hudType) { return hudType == HUD_TYPE.TANK }

    hudEventsList = [
      {
        eventName = "TankDebuffs:Repair"
        function getEventData() {
          return {
            state = u.chooseRandom(["notInRepair", "prepareRepair", "repairing"])
            time = 2 + rnd() % 10
          }
        }
      }
      {
        eventName = "TankDebuffs:Rearm"
        function getEventData() {
          return {
            state = u.chooseRandom(["notInRearm", "rearming"])
            timeToLoadOne = 1 + rnd() % 5
            currentLoadTime = 0.5 * (rnd() % 3)
            object_name = "rearm_status"
          }
        }
      }
      {
        eventName = ["TankCrew:DriverState", "TankCrew:GunnerState"]
        function getEventData() {
          return {
            state = u.chooseRandom(["takingPlace", "ok"])
            totalTakePlaceTime = 5 + rnd() % 10
            timeToTakePlace = 1 + rnd() % 4
          }
        }
      }
    ]
    function genNewEvent() {
      let hudEvent = u.chooseRandom(this.hudEventsList)
      local eventName = hudEvent.eventName
      if (u.isArray(eventName))
        eventName = u.chooseRandom(eventName)
      g_hud_event_manager.onHudEvent(eventName, hudEvent.getEventData())
    }
  }

  ZONE_CAPTURE = {
    eventChance = 30

    hudEventsTbl = {
      [MISSION_CAPTURED_ZONE] = {
        locId = "NET_TEAM1_CAPTURED_LA"
        isHeroAction = @() frnd() < 0.2
        captureProgress = 1
      },
      [MISSION_CAPTURING_ZONE] = {
        locId = "NET_YOU_CAPTURING_LA"
        isHeroAction = true
        captureProgress = @() 2.0 * frnd() - 1
      },
      [MISSION_CAPTURING_STOP] = {
        locId = "NET_TEAM_A_CAPTURING_STOP_LA"
        isHeroAction = true
        captureProgress = @() 2.0 * frnd() - 1
      }
    }

    function genNewEvent() {
      let drop = frnd()
      let eventId = drop < 0.7 ? MISSION_CAPTURING_ZONE
        : drop < 0.9 ? MISSION_CAPTURED_ZONE
        : MISSION_CAPTURING_STOP

      let hudEventData = { eventId = eventId }
      let data = this.hudEventsTbl[eventId]
      foreach (key, val in data)
        hudEventData[key] <- u.isFunction(val) ? val() : val

      hudEventData.zoneName <- u.chooseRandom(["A", "B", "C"])
      hudEventData.text <- format(loc(hudEventData.locId), hudEventData.zoneName)
      hudEventData.isMyTeam <- u.chooseRandom([true, false])
      g_hud_event_manager.onHudEvent("zoneCapturingEvent", hudEventData)
    }
  }

  REPAIR = {
    eventChance = 10

    hudEventsList = [
      { eventId = "tankRepair:offerRepair" }
      { eventId = "tankRepair:cantRepair" }
    ]
  }

  HUD_HINT = {
    eventChance = 10

    hudEventsList = [
      {
        eventId = "hint:bailout:startBailout"
        lifeTime = 15
        offenderName = "<offenderName>"
      }
      { eventId = "hint:bailout:offerBailout" }
      { eventId = "hint:bailout:notBailouts" }
      { eventId = "hint:xrayCamera:showSkipHint" }
      { eventId = "hint:xrayCamera:hideSkipHint" }
    ]
  }

  HUD_MISSION_HINT = {
    eventChance = 50

    hudEventsList = [
      {
        eventId = "hint:missionHint:set"
        shortcuts = [
          "@ID_ZOOM",
          "ID_ZOOM_TOGGLE",
          "@zoom=max",
        ]
        priority = 200
        locId = "hints/tutorialB_zoom_in"
        hintType = "standard"
      }
      {
        eventId = "hint:missionHint:set"
        priority = 0
        locId = "hints/enemy_base_destroyed_no_respawn"
        hintType = "standard"
      }
      {
        eventId = "hint:missionHint:set"
        priority = 0
        locId = "hints/enemy_base_destroyed"
        isOverFade = true
        hintType = "standard"
      }
      { eventId = "hint:missionHint:objectiveSuccess", objectiveType = OBJECTIVE_TYPE_PRIMARY, objectiveText = "" }
      { eventId = "hint:missionHint:objectiveAdded" }
      { eventId = "hint:missionHint:objectiveFail", objectiveType = OBJECTIVE_TYPE_PRIMARY, objectiveText = "" }
      { eventId = "hint:missionHint:remove", hintType = "standard" }
    ]
  },

  [HUD_MSG_DEATH_REASON] = {
    eventChance = 50

    hudEventsList = [
      {
        eventId = "HudMessage"
        type = HUD_MSG_DEATH_REASON
        text = loc("death/ammoExplosion")
        id = @() rnd()
        showInDamageLog = true
      }
    ]
  }

  AIR_STREAK_HINT = {
    eventChance = 50
    iconsList = ["aircraft_fighter", "aircraft_attacker", "aircraft_bomber"]
    textsList = ["hints/event_start_time", "hints/event_can_join_ally", "hints/event_can_join_enemy", "hints/event_player_start_on"]
    function genNewEvent() {
      let eventData = {
        participant = []
        timeSeconds = rnd() % 15 + 1
        locId = u.chooseRandom(this.textsList)
        shortcut = "ID_KILLSTREAK_WHEEL_MENU"
        slotsCount = 3
        playerId = 0
        player = getFakePlayer(0)
      }

      let pTotal = rnd() % 6 + 1
      for (local i = 0; i < pTotal; i++)
        eventData.participant.append({
          image = u.chooseRandom(this.iconsList)
          participantId = i
          player = getFakePlayer(i)
        })

      g_hud_event_manager.onHudEvent("hint:event_start_time:show", eventData)
    }
  }
})

return results