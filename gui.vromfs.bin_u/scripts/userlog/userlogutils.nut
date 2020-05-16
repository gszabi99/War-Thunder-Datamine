local u = require("sqStdLibs/helpers/u.nut")

function disableSeenUserlogs(idsList) {
  if (u.isEmpty(idsList))
    return

  local needSave = false
  foreach (id in idsList) {
    if (!id)
      continue

    local disableFunc = u.isString(id) ? ::disable_user_log_entry_by_id : ::disable_user_log_entry
    if (disableFunc(id))
    {
      needSave = true
      u.appendOnce(id, ::shown_userlog_notifications)
    }
  }

  if (needSave)
  {
    ::dagor.debug("Userlog: Disable seen logs: save online")
    ::save_online_job()
  }
}

return {
  disableSeenUserlogs = disableSeenUserlogs
}