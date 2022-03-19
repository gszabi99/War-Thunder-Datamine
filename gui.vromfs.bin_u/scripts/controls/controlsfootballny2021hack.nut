/**
 * Temporary hack, for NEW Year 2021 Football event.
 * PLEASE KEEP AT LEAST tryControlsRestore() FUNCTION ON PRODUCTION
 * FOR AT LEAST 3 MONTHS, UNTIL APRIL 2021.
 * It overrides the control preset for gamepad in Football mission,
 * and restores the original controls after the mission or on login.
 */

local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { forceSaveProfile } = require("scripts/clientState/saveProfile.nut")

const FOOTBALL_NY2021_BACKUP_SAVE_ID = "footballNy2021Backup"

local function shouldManageControls() {
  return (::is_xinput_device() || ::have_xinput_device()) && ::g_login.isProfileReceived()
}

local function removeSingleGamepadBtnId(hc, btnId) {
  return hc.filter(@(sc) sc.len() != 1 || sc[0]?.deviceId != ::JOYSTICK_DEVICE_0_ID || sc[0]?.buttonId != btnId)
}

local function addSingleGamepadBtnId(hc, btnId) {
  return removeSingleGamepadBtnId(hc, btnId).append([ { deviceId = ::JOYSTICK_DEVICE_0_ID, buttonId = btnId } ])
}

local function isHotkeyEmpty(hc) {
  return hc.len() == 0 || (hc.len() == 1 && hc[0].len() == 0)
}

//==============================================================================

local function tryControlsOverride()
{
  if (!shouldManageControls())
    return false
  if (::get_game_mode() != ::GM_DOMINATION || !::SessionLobby.getMissionName().contains("football"))
    return false
  if (::load_local_account_settings(FOOTBALL_NY2021_BACKUP_SAVE_ID) != null)
    return false

  local preset = ::g_controls_manager.getCurPreset()
  local hcPrimaryGun = preset.getHotkey("ID_FIRE_GM")
  local hcMachineGun = preset.getHotkey("ID_FIRE_GM_MACHINE_GUN")

  // Searching for a PrimaryGun/MachineGun shared shortcut (like RT by default).

  local sourceBtnId = null
  foreach (sm in hcMachineGun)
  {
    foreach (sp in hcPrimaryGun)
      if (sm.len() == 1 && sp.len() == 1
          && sm[0]?.deviceId == ::JOYSTICK_DEVICE_0_ID && sp[0]?.deviceId == ::JOYSTICK_DEVICE_0_ID
          && sm[0]?.buttonId == sp[0]?.buttonId)
      {
        sourceBtnId = sm[0]?.buttonId
        break
      }
    if (sourceBtnId != null)
      break
  }
  if (sourceBtnId == null)
    return false // No changes required.

  // Searching for a btn where ID_FIRE_GM_MACHINE_GUN can be moved.

  local preserveHotkeys = [
    "ID_FLIGHTMENU_SETUP" // Absolutely must have
    "ID_FIRE_GM" // Used to hit the ball
    "ID_FIRE_GM_MACHINE_GUN" // Used to jump
    "ID_TARGETING_HOLD_GM" // Used to watch the ball
    "ID_MPSTATSCREEN"
    "ID_CAMERA_NEUTRAL"
    "ID_TOGGLE_CHAT_TEAM"
    "ID_TOGGLE_CHAT"
    "ID_TOGGLE_CHAT_PARTY"
    "ID_TOGGLE_CHAT_SQUAD"
    "ID_TOGGLE_CHAT_MODE"
  ]

  local tryBtnIdOrder = [
    ::SHORTCUT.GAMEPAD_L2 // LT
    ::SHORTCUT.GAMEPAD_L1 // LB // This one will be chosen for our uncustomized presets.
    ::SHORTCUT.GAMEPAD_R1 // RB
    ::SHORTCUT.GAMEPAD_R2 // RT
    ::SHORTCUT.GAMEPAD_LSTICK_PRESS
    ::SHORTCUT.GAMEPAD_RSTICK_PRESS
    ::SHORTCUT.GAMEPAD_Y
    ::SHORTCUT.GAMEPAD_X
    ::SHORTCUT.GAMEPAD_UP
    ::SHORTCUT.GAMEPAD_DOWN
    ::SHORTCUT.GAMEPAD_LEFT
    ::SHORTCUT.GAMEPAD_RIGHT
  ].map(@(b) b.btn[0]) // Mapped to integer buttonIds

  foreach (hotkeyId in preserveHotkeys)
  {
    local hc = preset.getHotkey(hotkeyId)
    foreach (sc in hc)
      if (sc.len() == 1 && sc[0]?.deviceId == ::JOYSTICK_DEVICE_0_ID)
      {
        local delIdx = tryBtnIdOrder.indexof(sc[0]?.buttonId)
        if (delIdx != null)
          tryBtnIdOrder.remove(delIdx)
      }
  }
  if (tryBtnIdOrder.len() == 0)
    return false // Nothing to choose (extremely bad configured preset).

  local destinationBtnId = tryBtnIdOrder[0]

  ::dagor.debug($"FoolballNy2021Hack: ID_FIRE_GM_MACHINE_GUN will be moved from buttonId {sourceBtnId} to {destinationBtnId}")

  // Collecting the conflicting shortcuts to wipe.

  local original = {}
  local modified = {}

  foreach (hotkeyId, hc in preset.hotkeys)
  {
    local needWipe = false
    foreach (sc in hc)
      if (sc.len() == 1 && sc[0]?.deviceId == ::JOYSTICK_DEVICE_0_ID && sc[0]?.buttonId == destinationBtnId)
        needWipe = true

    if (needWipe) // For our uncustomized presets wipes 3 shortcuts: ID_ROCKETS, ID_ATGM, submarine_depth.
    {
      original[hotkeyId] <- clone hc
      modified[hotkeyId] <- removeSingleGamepadBtnId(hc, destinationBtnId)
    }

    if (hotkeyId == "ID_FIRE_GM_MACHINE_GUN")
    {
      original[hotkeyId] <- clone hc
      modified[hotkeyId] <- addSingleGamepadBtnId(removeSingleGamepadBtnId(hc, sourceBtnId), destinationBtnId)
    }
  }

  // Saving backup to profile.

  ::save_local_account_settings(FOOTBALL_NY2021_BACKUP_SAVE_ID, {
    datetime = ::get_charserver_time_sec()
    original = original.map(@(v) ::save_to_json(v))
    modified = modified.map(@(v) ::save_to_json(v))
  })
  if (::load_local_account_settings(FOOTBALL_NY2021_BACKUP_SAVE_ID) == null)
    return false // This case shouldn't happen. But we won't modify anything without a backup.

  // Logging.

  ::dagor.debug($"FoolballNy2021Hack: Modifying hotkeys:")
  foreach(hotkeyId, hc in original)
  {
    ::dagor.debug($"  {hotkeyId}")
    ::dagor.debug($"    from: {::save_to_json(hc)}")
    ::dagor.debug($"    to:   {::save_to_json(modified[hotkeyId])}")
  }

  // Modifying the preset.

  foreach (hotkeyId, hc in modified)
    preset.setHotkey(hotkeyId, hc)
  ::g_controls_manager.commitControls()
  forceSaveProfile()

  ::dagor.debug($"FoolballNy2021Hack: Done")
  return true
}

//==============================================================================

local function tryControlsRestore()
{
  if (!shouldManageControls())
    return false

  local blk = ::load_local_account_settings(FOOTBALL_NY2021_BACKUP_SAVE_ID)
  if (blk == null)
    return false // Nothing to restore.

  local preset = ::g_controls_manager.getCurPreset()
  local data = ::buildTableFromBlk(blk)

  ::dagor.debug($"FoolballNy2021Hack: Restoring hotkeys from backup:")
  ::debugTableData(data, 10)

  local original = data?.original.map(@(s) ::parse_json(s)) ?? {}
  local modified = data?.modified.map(@(s) ::parse_json(s)) ?? {}

  if (original.len() == modified.len())
  {
    foreach (hotkeyId, hc in original)
    {
      local curHc = preset.getHotkey(hotkeyId)
      local expectedHc = modified?[hotkeyId] ?? []
      if (::u.isEqual(curHc, expectedHc) || (isHotkeyEmpty(curHc) && isHotkeyEmpty(expectedHc)))
      {
        preset.setHotkey(hotkeyId, hc)
        ::dagor.debug($"  OK   {hotkeyId}")
      }
      else
        ::dagor.debug($"  SKIP {hotkeyId}, current state is different: {::save_to_json(curHc)}")
    }
    ::g_controls_manager.commitControls()
  }

  ::save_local_account_settings(FOOTBALL_NY2021_BACKUP_SAVE_ID, null) // Deleting backup.
  forceSaveProfile()

  ::dagor.debug($"FoolballNy2021Hack: Done")
  return true
}

//==============================================================================

addListenersWithoutEnv({
  MissionStarted = @(p) tryControlsOverride()
  SessionDestroyed = @(p) tryControlsRestore()
  ProfileReceived = @(p) tryControlsRestore()
})
