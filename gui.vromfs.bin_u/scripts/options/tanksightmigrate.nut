from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import get_save_load_path, get_cur_circuit_name
from "%scripts/invalid_user_id.nut" import INVALID_USER_ID

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { dir_exists, move_folder } = require("dagor.fs")
let { join, normalize } = require("%sqstd/path.nut")
let { debug } = require("dagor.debug")
let { isPC } = require("%sqstd/platform.nut")
let { update_tank_sight_presets } = require("tankSightSettings")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { get_game_dir } = require("knownFolders")

let hasMigratedUserSights = mkWatched(persist, "hasMigratedUserSights", false)
let saveDataDir = mkWatched(persist, "saveDataDir", "")

function migrateUserSights() {
  if (!isPC)
    return
  if (userIdStr.get() == INVALID_USER_ID)
    return
  saveDataDir.set(join(normalize(get_save_load_path()), normalize($"/{userIdStr.get()}/{get_cur_circuit_name()}/UserSights")))
  let gameDir = join(normalize(get_game_dir()), "/UserSights")
  if (dir_exists(gameDir) && !dir_exists(saveDataDir.get())) {
    debug($"Migrating user sights from {gameDir} to {saveDataDir.get()}")
    move_folder(gameDir, saveDataDir.get())
    hasMigratedUserSights.set(true)
    update_tank_sight_presets()
  }
}

function showUserSightMigrationPopupIfNeeded() {
  if (hasMigratedUserSights.get()) {
    hasMigratedUserSights.set(false)
    showInfoMsgBox(($"{loc("msgbox/user_sights_migration")}\n{saveDataDir.get()}"), "user_sights_migration")
  }
}

addListenersWithoutEnv({
  LoginComplete = @(_) migrateUserSights()
})

return { showUserSightMigrationPopupIfNeeded }
