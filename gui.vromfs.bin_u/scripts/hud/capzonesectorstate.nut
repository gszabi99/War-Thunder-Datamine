import "%sqstd/ecs.nut" as ecs
from "math" import fabs
from "guiMission" import MISSION_CAPTURING_ZONE, MISSION_CAPTURING_STOP
from "%scripts/dagui_library.nut" import *
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

let sectors = {}
let heroSectorEid = Watched(ecs.INVALID_ENTITY_ID)
local isShown = false

let isCaptureRunning = @(sector) sector.progress != 0.0 && fabs(sector.progress) < 1.0

function sendCapturing(sector) {
  isShown = true
  g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    eventId = MISSION_CAPTURING_ZONE
    zoneName = $"{sector.index + 1}"
    captureProgress = sector.progress
    isHeroAction = true
  })
}

function sendStop() {
  isShown = false
  g_hud_event_manager.onHudEvent("zoneCapturingEvent", {
    eventId = MISSION_CAPTURING_STOP
    zoneName = ""
    captureProgress = 0.0
    isHeroAction = true
  })
}

function syncHeroRing() {
  let sector = sectors?[heroSectorEid.get()]
  if (sector != null && isCaptureRunning(sector))
    sendCapturing(sector)
  else if (isShown)
    sendStop()
}

heroSectorEid.subscribe(@(_) syncHeroRing())

function onSectorUpdate(eid, comp) {
  sectors[eid] <- {
    index = comp.capzone_sector__index
    progress = comp.capzone_sector__progress
  }
  if (eid == heroSectorEid.get())
    syncHeroRing()
}

function onSectorDestroy(eid) {
  sectors.$rawdelete(eid)
  if (eid == heroSectorEid.get())
    syncHeroRing()
}

ecs.register_es("capzone_sector_hero_track_ui",
  {
    [["onInit", "onChange"]] = @(_eid, comp) heroSectorEid.set(comp.capturer__sectorEid)
    onDestroy = @() heroSectorEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_no = ["isReplayObserved"]
    comps_track = [["capturer__sectorEid", ecs.TYPE_EID]]
  }
)

ecs.register_es("capzone_sector_progress_track_ui",
  {
    [["onInit", "onChange"]] = onSectorUpdate
    onDestroy = @(eid, _comp) onSectorDestroy(eid)
  },
  {
    comps_rq = ["capzoneSector"]
    comps_ro = [["capzone_sector__index", ecs.TYPE_INT]]
    comps_track = [["capzone_sector__progress", ecs.TYPE_FLOAT]]
  }
)
