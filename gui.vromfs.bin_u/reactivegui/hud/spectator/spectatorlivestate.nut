from "%rGui/globals/ui_library.nut" import *
from "dagor.workcycle" import setInterval, clearTimer
from "%sqstd/underscore.nut" import isEqual
from "app" import isGamePaused
from "replays" import get_time_speed, get_replay_anchors
from "hudState" import is_replay_markers_enabled
from "mission" import get_mission_time
from "camera_control" import isSensorViewMode
from "guiScriptUtils" import is_spectator_rotation_forced

const UPDATE_SEC = 0.3

let isReplayPaused = Watched(false)
let replayTimeSpeed = Watched(1.0)
let replayAnchors = Watched([])
let isReplayMarkersOn = Watched(false)
let missionTime = Watched(0.0)
let isSensorView = Watched(false)
let isCameraRotationForced = Watched(false)

function updateLiveState() {
  isReplayPaused.set(isGamePaused())
  replayTimeSpeed.set(get_time_speed())
  isReplayMarkersOn.set(is_replay_markers_enabled())
  missionTime.set(get_mission_time())
  isSensorView.set(isSensorViewMode())
  isCameraRotationForced.set(is_spectator_rotation_forced())
  let anchors = get_replay_anchors()
  if (!isEqual(anchors, replayAnchors.get()))
    replayAnchors.set(anchors)
}

function startLiveUpdates() {
  updateLiveState()
  setInterval(UPDATE_SEC, updateLiveState)
}


function stopLiveUpdates() {
  clearTimer(updateLiveState)
  isReplayPaused.set(false)
  replayTimeSpeed.set(1.0)
  replayAnchors.set([])
  isReplayMarkersOn.set(false)
  missionTime.set(0.0)
  isSensorView.set(false)
  isCameraRotationForced.set(false)
}


let findAnchorIdx = @(timeSec, anchors) (anchors.findindex(@(v) v > timeSec * 1000) ?? anchors.len()) - 1

let curAnchorIdx = Computed(@() findAnchorIdx(missionTime.get(), replayAnchors.get()))

return freeze({
  isReplayPaused
  replayTimeSpeed
  replayAnchors
  findAnchorIdx
  curAnchorIdx
  isReplayMarkersOn
  missionTime
  isSensorView
  isCameraRotationForced
  startLiveUpdates
  stopLiveUpdates
})
