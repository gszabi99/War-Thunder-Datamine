from "%scripts/dagui_natives.nut" import is_myself_chat_moderator, clan_request_sync_profile, wp_shop_get_aircraft_xp_rate, direct_launch, chard_request_profile, get_player_army_for_hud, is_myself_grand_moderator, wp_shop_get_aircraft_wp_rate, clan_get_my_clan_id, sync_handler_simulate_request, is_myself_moderator
from "app" import exitGame
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_current_base_gui_handler } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")


let penalty = require("penalty")
let { startLogout } = require("%scripts/login/logout.nut")
let { quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let { add_msg_box, remove_scene_box } = require("%sqDagui/framework/msgBox.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { is_mode_with_teams } = require("%scripts/utils_sa.nut")
let { getShopCountry } = require("%scripts/shop/shopCountryInfo.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")

local gui_start_logout_scheduled = false

dagui_propid_add_name_id("tooltipId")

eventbus_subscribe("on_cannot_create_session", function on_cannot_create_session(...) {
  add_msg_box("cannot_session", loc("NET_CANNOT_CREATE_SESSION"), [["ok", function() {}]], "ok")
})


function on_lost_psn() {
  log("on_lost_psn")
  let guiScene = get_gui_scene()
  let handler = get_current_base_gui_handler()
  if (handler == null)
    return

  remove_scene_box("connection_failed")

  if (guiScene["list_no_sessions_create"] != null) {
    remove_scene_box("list_no_sessions_create")
  }
  if (guiScene["psn_room_create_error"] != null) {
    remove_scene_box("psn_room_create_error")
  }

  if (!isInMenu.get()) {
    gui_start_logout_scheduled = true
    destroySessionScripted("on lost psn while not in menu")
    quit_to_debriefing()
    interrupt_multiplayer(true)
  }
  else {
    add_msg_box("lost_live", loc("yn1/disconnection/psn"), [["ok",
        function() {
          destroySessionScripted("after 'on lost psn' message")
          startLogout()
        }
        ]], "ok")
  }
}

eventbus_subscribe("PsnLoginStateChanged", @(p) p?.isSignedIn ? null : on_lost_psn())

::check_logout_scheduled <- function check_logout_scheduled() {
  if (gui_start_logout_scheduled) {
    gui_start_logout_scheduled = false
    on_lost_psn()
  }
}

::getCountryByAircraftName <- function getCountryByAircraftName(airName) { 
  let country = getShopCountry(airName)
  let cPrefixLen = "country_".len()
  if (country.len() > cPrefixLen)
    return country.slice(cPrefixLen)
  return ""
}

eventbus_subscribe("on_have_to_start_chard_op", function on_have_to_start_chard_op(data) {
  let { message } = data
  log($"on_have_to_start_chard_op {message}")

  if (message == "sync_clan_vs_profile") {
    let taskId = clan_request_sync_profile()
    addBgTaskCb(taskId, function() {
      ::requestMyClanData(true)
      updateGamercards()
    })
  }
  else if (message == "clan_info_reload") {
    ::requestMyClanData(true)
    let myClanId = clan_get_my_clan_id()
    if (myClanId == "-1")
      sync_handler_simulate_request(message)
  }
  else if (message == "profile_reload") {
    let oldPenaltyStatus = penalty.getPenaltyStatus()
    let taskId = chard_request_profile()
    addBgTaskCb(taskId, function() {
      let  newPenaltyStatus = penalty.getPenaltyStatus()
      if (newPenaltyStatus.status != oldPenaltyStatus.status || newPenaltyStatus.duration != oldPenaltyStatus.duration)
        broadcastEvent("PlayerPenaltyStatusChanged", { status = newPenaltyStatus.status })
    })
  }
})

::quit_and_run_cmd <- function quit_and_run_cmd(cmd) {
  direct_launch(cmd); 
  exitGame();
}

::cross_call_api.is_mode_with_teams <- is_mode_with_teams
