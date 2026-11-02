import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/components/toolbarButton.nut" as toolbarButton
import "%appGlobals/style/cssColors.nut" as cssColors
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
from "%appGlobals/hud/spectatorState.nut" import spectatorSession, spectatorCameraTarget, isReplaySystemWindowOpened
from "%rGui/hud/spectator/spectatorLiveState.nut" import isReplayPaused, replayTimeSpeed, replayAnchors, curAnchorIdx,
  findAnchorIdx, isReplayMarkersOn, missionTime, isSensorView, isCameraRotationForced
from "%appGlobals/timeLoc.nut" import secondsToString
from "%globalScripts/controls/shortcutActions.nut" import toggleShortcut
from "eventbus" import eventbus_send
from "replays" import move_to_anchor, get_replay_anchors
from "mission" import get_mission_time
from "string" import format
from "math" import fabs

let font = fontsState.get("normal")
let btnSize = cssConst("spectatorToolbarBtnSize")
let toolbarPadding = cssConst("spectatorToolbarPadding")
let iconSize = cssConst("sIco")
let blockMargin = [0, (0.25 * btnSize).tointeger()]
let timeTextWidth = px("0.10@sf")
let shortTextWidth = px("0.07@sf")
let progressWidth = cssConst("spectatorTimerProgressWidth")
let progressHeight = cssConst("progressHeight")
let dpPx = cssConst("dp")
let anchorMarkSize = [6 * dpPx, progressHeight + 7 * dpPx]

function formatReplayTime(value) {
  let sign = value >= 0 ? "" : loc("ui/minus")
  let ms = (fabs(value) * 1000.0 + 0.5).tointeger()
  return format("%s%d:%02d.%03d", sign, ms / 60000, ms % 60000 / 1000, ms % 1000)
}

function mkTooltip(id, hotkeys) {
  let hotkey = hotkeys?[id] ?? ""
  let text = loc($"hotkeys/{id}")
  return hotkey == "" ? @() text
    : @() "".concat(text, "<color=@hotkeyColor>", loc("ui/parentheses/space", { text = hotkey }), "</color>")
}

let moveToNextAnchor = @(direction) function() {
  let anchors = get_replay_anchors()
  let idx = findAnchorIdx(get_mission_time(), anchors) + direction
  if (idx >= 0 && idx < anchors.len())
    move_to_anchor(idx)
}

let canGoBack = Computed(@() curAnchorIdx.get() >= 0)
let canGoForward = Computed(@() curAnchorIdx.get() + 1 < replayAnchors.get().len())
let cameraTargetValid = Computed(@() spectatorCameraTarget.get()?.isValid ?? false)
let cameraTargetFollow = Computed(@() spectatorCameraTarget.get()?.isFollowActive ?? false)
let cameraTargetHover = Computed(@() cameraTargetValid.get() && !(spectatorCameraTarget.get()?.isAircraft ?? false))
let canSwitchPlane = Computed(@() spectatorSession.get()?.canSwitchPlane ?? false)
let canSlowDown = Computed(@() replayTimeSpeed.get() > (spectatorSession.get()?.timeSpeedMin ?? 1.0))
let canSpeedUp = Computed(@() replayTimeSpeed.get() < (spectatorSession.get()?.timeSpeedMax ?? 1.0))

let mkFixedText = @(text, width) mkText(text, font, cssColors.commonTextColor,
  { size = [width, SIZE_TO_CONTENT], halign = ALIGN_CENTER, vplace = ALIGN_CENTER })

function mkCameraIcon() {
  return {
    size = btnSize
    children = {
      size = iconSize
      pos = [btnSize - (1.2 * iconSize).tointeger(), 0]
      vplace = ALIGN_CENTER
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#player_spectator.svg:{iconSize}:{iconSize}:K")
      color = 0x4C4C4C4C
    }
  }
}

let speedText = @() mkFixedText(format("%.3fx", replayTimeSpeed.get()), shortTextWidth)
  .__update({ watch = replayTimeSpeed })

let currentTimeText = @() mkFixedText(formatReplayTime(missionTime.get()), timeTextWidth)
  .__update({ watch = missionTime })

let missionTimer = @() mkFixedText(secondsToString(missionTime.get(), false), shortTextWidth)
  .__update({ watch = missionTime, margin = blockMargin })

function mkAnchorMark(timeMsec, idx, timeTotal) {
  let sf = Watched(0)
  let key = $"replayAnchor{idx}"
  let timeSec = timeMsec / 1000.0
  let onElemState = withHint(sf, key, @() loc("replay/move_to_time", { time = formatReplayTime(timeSec) }))
  let onDetach = tooltipDetach(sf, key)
  return @() {
    watch = sf
    key
    size = anchorMarkSize
    pos = [(progressWidth * timeSec / timeTotal).tointeger() - 2 * dpPx, 0]
    vplace = ALIGN_BOTTOM
    behavior = Behaviors.Button
    onElemState
    onDetach
    onClick = @() move_to_anchor(idx)
    children = {
      size = [2 * dpPx, flex()]
      hplace = ALIGN_CENTER
      rendObj = ROBJ_SOLID
      color = (sf.get() & S_ACTIVE) != 0 ? 0xFF008500
        : (sf.get() & S_HOVER) != 0 ? 0xFF67E667
        : 0xFF00CC00
    }
  }
}

function mkTimelineProgress(timeTotal) {
  return function() {
    let part = timeTotal > 0 ? clamp(missionTime.get() / timeTotal, 0.0, 1.0) : 0.0
    return {
      watch = missionTime
      size = [progressWidth, progressHeight]
      rendObj = ROBJ_SOLID
      color = cssColors.cardProgressBGColor
      children = { size = [pw(100 * part), flex()], rendObj = ROBJ_SOLID, color = cssColors.cardProgressFGColor }
    }
  }
}

function mkAnchorMarks(timeTotal) {
  return @() {
    watch = replayAnchors
    size = [progressWidth, progressHeight]
    children = replayAnchors.get().map(@(timeMsec, idx) mkAnchorMark(timeMsec, idx, timeTotal)) 
  }
}

function mkTimeline(timeTotal, canRewind) {
  return {
    vplace = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      currentTimeText
      {
        children = [
          mkTimelineProgress(timeTotal)
          canRewind && timeTotal > 0 ? mkAnchorMarks(timeTotal) : null
        ]
      }
      mkFixedText(formatReplayTime(timeTotal), timeTextWidth)
    ]
  }
}

function mkToolbarButtons(session) {
  let { isReplay, isReplayCamera, isTouch, canControlTimeline, canControlCameras,
    canSeeMissionTimer, canRewind, hasSystemWindow, timeTotal, hotkeys } = session

  let mkShortcutBtn = @(id, p) toolbarButton({ id, tooltip = mkTooltip(id, hotkeys), ...p }, @() toggleShortcut(id))
  let cameraBtn = @(id, text, isEnabled = cameraTargetValid) mkShortcutBtn(id, { text, isEnabled })
  let anchorBtn = @(id, direction, iconRotate, isEnabled)
    toolbarButton({ id, icon = "replay_restart", iconRotate, isEnabled, tooltip = mkTooltip(id, hotkeys) },
      moveToNextAnchor(direction))

  return [
    isTouch ? mkShortcutBtn("ID_FLIGHTMENU", { icon = "btn_modifications" }) : null
    !isReplay ? mkShortcutBtn("ID_MPSTATSCREEN", { icon = "leaderboard" })
      : toolbarButton({ id = "controls_mpstats_replays", icon = "leaderboard", tooltip = @() loc("hotkeys/ID_MPSTATSCREEN") },
          @() eventbus_send("spectatorOpenMpStats", {}))
    mkShortcutBtn("ID_PREV_PLANE", { icon = "spinnerListBox_arrow_up", iconRotate = 270, isEnabled = canSwitchPlane })
    mkShortcutBtn("ID_NEXT_PLANE", { icon = "spinnerListBox_arrow_up", iconRotate = 90, isEnabled = canSwitchPlane })
    canControlCameras ? mkCameraIcon() : null
    canControlCameras ? cameraBtn("ID_CAMERA_DEFAULT", "1") : null
    canControlCameras ? cameraBtn("ID_TOGGLE_FOLLOWING_CAMERA", "2", cameraTargetFollow) : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_OPERATOR", "3") : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_FLYBY", "4") : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_WING", "5") : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_GUN", "6") : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_RANDOMIZE", loc("mainmenu/btnReplayCameraRandom")) : null
    canControlCameras ? cameraBtn("ID_REPLAY_CAMERA_FREE", loc("mainmenu/btnReplayCameraFree")) : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_FREE_PARENTED", loc("mainmenu/btnReplayCameraFreeParented")) : null
    isReplayCamera ? cameraBtn("ID_REPLAY_CAMERA_FREE_ATTACHED", loc("mainmenu/btnReplayCameraFreeAttached")) : null
    canControlCameras ? cameraBtn("ID_REPLAY_CAMERA_HOVER", loc("mainmenu/btnReplayCameraHover"), cameraTargetHover) : null
    mkShortcutBtn("ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT", { icon = "cursor", isHighlighted = isCameraRotationForced })
    isReplay ? mkShortcutBtn("ID_REPLAY_SHOW_MARKERS",
      { text = loc("icon/mpstats/raceLastCheckpoint"), isHighlighted = isReplayMarkersOn }) : null
    isReplay ? mkShortcutBtn("ID_REPLAY_TOGGLE_SENSOR_VIEW", { icon = "replay_nightvision", isHighlighted = isSensorView })
      : null
    hasSystemWindow ? mkShortcutBtn("ID_REPLAY_SYSTEM_WINDOW",
      { icon = "replay_camera_control", isHighlighted = isReplaySystemWindowOpened }) : null
    canControlTimeline ? mkShortcutBtn("ID_REPLAY_SLOWER", { icon = "replay_forward", iconRotate = 180, isEnabled = canSlowDown })
      : null
    canControlTimeline ? speedText : null
    canControlTimeline ? mkShortcutBtn("ID_REPLAY_FASTER", { icon = "replay_forward", isEnabled = canSpeedUp }) : null
    canRewind ? anchorBtn("ID_REPLAY_BACKWARD", -1, 0, canGoBack) : null
    canControlTimeline
      ? mkShortcutBtn("ID_REPLAY_PAUSE", { icon = "replay_pause", altIcon = "replay_play", isAltIcon = isReplayPaused })
      : null
    canRewind ? anchorBtn("ID_REPLAY_FORWARD", 1, 180, canGoForward) : null
    canControlTimeline ? mkTimeline(timeTotal, canRewind) : null
    canSeeMissionTimer ? missionTimer : null
  ]
}

function spectatorToolbar() {
  let session = spectatorSession.get()
  return {
    watch = spectatorSession
    hplace = ALIGN_CENTER
    pos = [0, -toolbarPadding - dpPx]
    rendObj = ROBJ_SOLID
    color = cssColors.frameSpectatorBackgroundColor
    children = {
      padding = toolbarPadding + dpPx
      rendObj = ROBJ_FRAME
      borderWidth = dpPx
      color = cssColors.frameSpectatorBorderColor
      children = {
        flow = FLOW_HORIZONTAL
        children = session == null ? null : mkToolbarButtons(session)
      }
    }
  }
}

return spectatorToolbar
