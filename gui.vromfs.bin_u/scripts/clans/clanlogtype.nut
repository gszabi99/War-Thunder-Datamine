//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let platformModule = require("%scripts/clientState/platform.nut")

::g_clan_log_type <- {
  types = []
}

::g_clan_log_type_cache <- {
  byName = {}
}

let isSelfLog = @(logEntry) logEntry?.uN == logEntry?.nick
let getColoredNick = @(logEntry)
  "<Link=uid_" + logEntry.uid + ">" + colorize(
    logEntry.uid == ::my_user_id_str ? "mainPlayerColor" : "userlogColoredText",
    platformModule.getPlayerName(logEntry.nick)
  ) + "</Link>"

::g_clan_log_type.template <- {
  name = ""
  logDetailsCommonFields = []
  logDetailsIndividualFields = []

  needDetails = @(_logEntry) true
  getLogHeader = @(_logEntry) ""

  getLogDetailsCommonFields = function() {
    let fields = ["admin"]
    fields.extend(this.logDetailsCommonFields)
    return fields
  }

  getLogDetailsIndividualFields = @() this.logDetailsIndividualFields

  getSignText = function(logEntry) {
    local name = logEntry?.uN
    if (!name)
      return null

    let uId = logEntry?.uId ?? ""

    let locId = logEntry?.admin ? "clan/log/initiated_by_admin" : "clan/log/initiated_by"
    let color = logEntry?.uId == ::my_user_id_str ? "mainPlayerColor" : "userlogColoredText"

    name = colorize(color, platformModule.getPlayerName(name))
    name = "<Link=uid_" + uId + ">" + name + "</Link>"

    return loc(locId, { nick = name })
  }
}

enums.addTypesByGlobalName("g_clan_log_type", {
  CREATE = {
    name = "create"
    logDetailsCommonFields = [
      "name"
      "type"
      "tag"
      "desc"
      "slogan"
      "region"
      "announcement"
    ]
    function getLogHeader(_logEntry) {
      return loc("clan/log/create_log")
    }
  }
  INFO = {
    name = "info"
    logDetailsCommonFields = [
      "name"
      "tag"
      "desc"
      "slogan"
      "region"
      "announcement"
      "status"
    ]
    function getLogHeader(_logEntry) {
      return loc("clan/log/change_info_log")
    }
  }
  UPGRADE = {
    name = "upgrade"
    logDetailsCommonFields = [
      "type"
      "tag"
      "desc"
    ]
    function getLogHeader(_logEntry) {
      return loc("clan/log/upgrade_log")
    }
  }
  ADD = {
    name = "add"
    logDetailsCommonFields = [
      "uid"
      "nick"
      "role"
    ]
    needDetails = @(logEntry) !isSelfLog(logEntry)
    function getLogHeader(logEntry) {
      return loc("clan/log/add_new_member_log", { nick = getColoredNick(logEntry) })
    }
  }
  REMOVE = {
    name = "rem"
    logDetailsCommonFields = [
      "uid"
      "nick"
    ]
    needDetails = @(logEntry) !isSelfLog(logEntry)
    function getLogHeader(logEntry) {
      let locId = isSelfLog(logEntry) ? "clan/log/leave_member_log" : "clan/log/remove_member_log"
      return loc(locId, { nick = getColoredNick(logEntry) })
    }
  }
  ROLE = {
    name = "role"
    logDetailsCommonFields = [
      "uid"
      "nick"
    ]
    logDetailsIndividualFields = [
      "old"
    ]
    function getLogHeader(logEntry) {
      return loc("clan/log/change_role_log", {
        nick = getColoredNick(logEntry),
        role = colorize("@userlogColoredText", loc("clan/" + (logEntry?.new ?? "")))
      })
    }
  }
  UPGRADE_MEMBERS = {
    name = "upgrade_members"
    logDetailsIndividualFields = [
      "old"
      "new"
    ]
    function getLogHeader(logEntry) {
      return loc("clan/log/upgrade_members_log", { nick = logEntry.uN })
    }
  }
  REJECT_CANDIDATE = {
    name = "reject_candidate"
    logDetailsCommonFields = [
      "uid"
      "nick"
      "comments"
    ]
    function getLogHeader(logEntry) {
      return loc("clan/log/reject_candidate_log", { nick = getColoredNick(logEntry) })
    }
  }
  ADD_TO_BLACKLIST = {
    name = "add_to_blacklist"
    logDetailsCommonFields = [
      "uid"
      "nick"
      "comments"
    ]
    function getLogHeader(logEntry) {
      return loc("clan/log/add_to_blacklist_log", { nick = getColoredNick(logEntry) })
    }
  }
  REMOVE_FROM_BLACKLIST = {
    name = "remove_from_blacklist"
    logDetailsCommonFields = [
      "uid"
      "nick"
      "comments"
    ]
    function getLogHeader(logEntry) {
      return loc("clan/log/remove_from_blacklist_log", { nick = getColoredNick(logEntry) })
    }
  }
  UNKNOWN = {}
})

::g_clan_log_type.getTypeByName <- function getTypeByName(name) {
  return enums.getCachedType("name", name, ::g_clan_log_type_cache.byName,
                                       ::g_clan_log_type, ::g_clan_log_type.UNKNOWN)
}
