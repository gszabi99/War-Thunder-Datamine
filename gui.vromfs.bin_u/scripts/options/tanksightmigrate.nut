from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { normalize } = require("%sqstd/path.nut")

let hasMigratedUserSights = mkWatched(persist, "hasMigratedUserSights", false)
let userSightMigrationParam = mkWatched(persist, "userSightMigrationParam", {})

function showUserSightMigrationPopupIfNeeded() {
  if (!hasMigratedUserSights.get())
    return
  hasMigratedUserSights.set(false)
  if (userSightMigrationParam.get().result == true)
    showInfoMsgBox(($"{loc("msgbox/user_sights_migration")}\n{normalize(userSightMigrationParam.get().newPath)}"), "user_sights_migration")
  else
    showInfoMsgBox(
      loc("msgbox/user_sights_migration_failed", {
        oldPath = normalize(userSightMigrationParam.get().oldPath)
        newPath = normalize(userSightMigrationParam.get().newPath)
      }), "user_sights_migration_failed")
}

eventbus_subscribe("OnTankSightMigrationFinished", function(p) {
  hasMigratedUserSights.set(true)
  userSightMigrationParam.set(p)
})

return { showUserSightMigrationPopupIfNeeded }
