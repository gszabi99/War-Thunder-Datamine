import "%sqstd/ecs.nut" as ecs
from "%scripts/dagui_library.nut" import *
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")


let defMiningWallInfo = {
  isMiningWall = false
  miningWallTimeTotal = 0.0
}

let miningWallInfo = Watched(defMiningWallInfo)
miningWallInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("miningWallInProgress", v))


let isBombPlantingAvailable = Watched(false)
isBombPlantingAvailable.subscribe(@(v) g_hud_event_manager.onHudEvent( v
  ? "hint:human_mine_the_wall_show"
  : "hint:human_mine_the_wall_hide"
))


let defPlantedBombInfo = freeze({
  curPlantedExplosionAtTime = -1.0
  curPlantedExplosionDelay = -1.0
})

let plantedBombInfo = Watched(defPlantedBombInfo)
plantedBombInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("plantedBombInProgress", v))


ecs.register_es("mining_wall_available_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      isBombPlantingAvailable.set(comp.human_mining_wall__isPlantingAvailable)
    }
    onDestroy = function() {
      isBombPlantingAvailable.set(false)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[["human_mining_wall__isPlantingAvailable", ecs.TYPE_BOOL]]
  }
)


ecs.register_es("mining_wall_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      miningWallInfo.set({
        isMiningWall = comp.human_mining_wall__plantingStartTime > 0.0
        miningWallTimeTotal = comp.human_mining_wall__plantingDuration
      })
    }
    onDestroy = function() {
      miningWallInfo.set(defMiningWallInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_ro=[["human_mining_wall__plantingDuration", ecs.TYPE_FLOAT]]
    comps_track=[["human_mining_wall__plantingStartTime", ecs.TYPE_FLOAT]]
  }
)

ecs.register_es("planted_bomb_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      plantedBombInfo.set({
        curPlantedExplosionAtTime = comp.human_mining_wall__curPlantedExplosionAtTime
        curPlantedExplosionDelay = comp.human_mining_wall__curPlantedExplosionDelay
      })
    }
    onDestroy = function() {
      plantedBombInfo.set(defPlantedBombInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["human_mining_wall__curPlantedExplosionAtTime", ecs.TYPE_FLOAT],
      ["human_mining_wall__curPlantedExplosionDelay", ecs.TYPE_FLOAT]
    ]
  }
)

let showReassembleWallTip = Watched(false)
showReassembleWallTip.subscribe(@(v) g_hud_event_manager.onHudEvent( v
  ? "hint:human_build_the_wall_show"
  : "hint:human_build_the_wall_hide"
))


let defaultReassembleWallInfo = freeze({
  isReassemblingWall = false
  reassemblingEndTime = 0.0
  reassemblingTotalTime = 0.0
})
let reassemblingWallInfo = Watched(defaultReassembleWallInfo)
reassemblingWallInfo.subscribe(@(v) g_hud_event_manager.onHudEvent("buildingWallInProgress", v))


ecs.register_es("reassembling_wall_available_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      showReassembleWallTip.set(comp.human_mining_wall__isReassemblingAvailable)
    }
    onDestroy = function() {
      showReassembleWallTip.set(false)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[["human_mining_wall__isReassemblingAvailable", ecs.TYPE_BOOL]]
  }
)

ecs.register_es("reassembling_wall_track_ui",
  {
    [["onInit", "onChange"]] = function(_, comp) {
      reassemblingWallInfo.set({
        isReassemblingWall = comp.human_mining_wall__reassemblingStartTime > 0.0
        reassemblingEndTime = comp.human_mining_wall__reassemblingEndTime
        reassemblingTotalTime = comp.human_mining_wall__reassemblingDuration
      })
    }
    onDestroy = function() {
      reassemblingWallInfo.set(defaultReassembleWallInfo)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_ro=[["human_mining_wall__reassemblingDuration", ecs.TYPE_FLOAT]]
    comps_track=[
      ["human_mining_wall__reassemblingStartTime", ecs.TYPE_FLOAT],
      ["human_mining_wall__reassemblingEndTime", ecs.TYPE_FLOAT],
    ]
  }
)