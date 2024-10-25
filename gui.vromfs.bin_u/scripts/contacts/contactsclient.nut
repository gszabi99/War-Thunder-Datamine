from "%scripts/dagui_library.nut" import *
let lowLevelClient = require("contacts")
let { getPlayerTokenGlobal } = require("auth_wt")
let { APP_ID } = require("app")
let { register_command } = require("console")
let { rnd_int } = require("dagor.random")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { GAME_GROUP_NAME } = require("%scripts/contacts/contactsConsts.nut")
let logC = log_with_prefix("[CONTACTS CLIENT] ")

local lastRequestId = rnd_int(0, 32767)

function lowLevelClientRequest(requestData, callback) {
  lowLevelClient.request(requestData, function(result) {
    let errorStr = result?.error ?? result?.result?.error
    if (errorStr != null) {
      let colonPos = errorStr.indexof(":")
      let errorName = colonPos != null ? errorStr.slice(0, colonPos) : errorStr
      let errorDetails = colonPos != null ? errorStr.slice(colonPos + 1) : null
      callback( { result = {
        success = false,
        error = errorName,
        errorDetails = errorDetails
      }})
    }
    else {
      callback(result)
    }
  })
}

function contacts_request(action, data, callback, auth_token = null) {
  if (!::g_login.isLoggedIn()) {
    logC("User is logout skip contacts_request")
    return
  }

  auth_token = auth_token ?? getPlayerTokenGlobal()
  assert(auth_token != null, "No auth token provided for contacts request")
  let request = {
    headers = {token = auth_token, appid = APP_ID},
    action = action
  }

  if (data) {
    request["data"] <- data
  }

  lowLevelClientRequest(request, callback)
}

function contacts_request_rpcjson(action, data, callback, auth_token = null) {
  if (!::g_login.isLoggedIn()) {
    logC("User is logout skip contacts_request")
    return
  }

  auth_token = auth_token ?? getPlayerTokenGlobal()
  assert(auth_token != null, "No auth token provided for contacts request")
  let reqData = {
    method = action
    id = ++lastRequestId
    jsonrpc = "2.0"
  }.__update(data ?? {})

  let requestData = {
    headers = {
      appid = APP_ID
      token = auth_token
    }
    action
    data = reqData
  }

  lowLevelClientRequest(requestData, callback)
}

function perform_contact_action(action, request, params) {
  let onSuccessCb = params?.success
  local onFailureCb = params?.failure

  logC("perform_contact_action", request)

  contacts_request(action, request, function(result) {
    logC("contacts_request", result)

    let subResult = result?.result
    if (subResult != null)
      result = subResult

    // Failure only if its explicitly defined in result
    if ("success" in result && !result.success) {
      if (typeof onFailureCb == "function") {
        onFailureCb(result?.error)
      }
    } else {
      if (typeof onSuccessCb == "function") {
        onSuccessCb()
      }
      logC("Ok")
    }
  })
}

function perform_single_contact_action(request, params) {
  perform_contact_action("cln_change_single_contact_json", request, params)
}

function contacts_add(id, params = {}) {
  let request = {
    friend = {
      add = [id]
    }
  }

  perform_single_contact_action(request, params)
}


function contacts_remove(id, params = {}) {
  let request = {
    friend = {
      remove = [id]
    }
  }
  perform_single_contact_action(request, params)
}

function perform_contacts_for_requestor(action, apprUid, group, params = {}, requestAddon = {}) {
  if (apprUid == ::INVALID_USER_ID) {
    logC($"try perform action {action} for invalid contact, group {group}")
    return
  }

  let request = {
    apprUid = apprUid
    groupName = group
  }
  perform_contact_action(action, request.__merge(requestAddon), params)
}

function perform_contacts_for_approver(action, requestorUid, group, params = {}, requestAddon = {}) {
  if (requestorUid == ::INVALID_USER_ID) {
    logC($"try perform action {action} for invalid contact, group {group}")
    return
  }

  let request = {
    requestorUid = requestorUid
    groupName = group
  }
  perform_contact_action(action, request.__merge(requestAddon), params)
}

let contactsClient = {
  low_level_client = lowLevelClient
  contacts_request = contacts_request
  contacts_request_rpcjson
  perform_contacts_for_requestor = perform_contacts_for_requestor
  perform_contacts_for_approver = perform_contacts_for_approver
  contacts_add = contacts_add
  contacts_remove = contacts_remove
  perform_single_contact_action = perform_single_contact_action
  perform_contact_action = perform_contact_action

  function contacts_request_for_contact(id, group, params = {}) {
    perform_contacts_for_requestor("cln_request_for_contact", id, group, params)
  }

  function contacts_cancel_request(id, group, params = {}) {
    perform_contacts_for_requestor("cln_cancel_request_for_contact", id, group, params)
  }

  function contacts_approve_request(id, group, params = {}) {
    perform_contacts_for_approver("cln_approve_request_for_contact", id, group, params)
  }

  function contacts_break_approval_request(id, group, params = {}) {
    perform_contacts_for_approver("cln_break_approval_contact", id, group, params)
  }

  function contacts_reject_request(id, group, params = {}) {
    perform_contacts_for_approver("cln_reject_request_for_contact", id, group, params, {silent="on"})
  }

  function contacts_add_to_blacklist(id, group, params = {}) {
    perform_contacts_for_approver("cln_blacklist_request_for_contact", id, group, params)
  }

  function contacts_remove_from_blacklist(id, group, params = {}) {
    perform_contacts_for_approver("cln_remove_from_blacklist_for_contact", id, group, params)
  }

}

// console commands
function contacts_get() {
  contacts_request_rpcjson("GetContacts",  { groups = [GAME_GROUP_NAME] }
    @(result) logC("GetContacts", result))
}

function contacts_search(nick) {
  let request = {
    nick = nick
    max_count = 10
    ignore_case = true
  }

  contacts_request("cln_find_users_by_nick_prefix_json", request, function(result) {
    logC("cln_find_users_by_nick_prefix_json result", result)
  })
}

addListenersWithoutEnv({
  function SignOut(_) {
    lowLevelClient.clearCallbacks()
    lowLevelClient.clearEvents()
  }
})

register_command(contacts_get, "contacts.contacts_get")
register_command(contacts_add, "contacts.contacts_add")
register_command(contacts_search, "contacts.contacts_search")

return contactsClient
