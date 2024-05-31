//-file:plus-string
from "%scripts/dagui_natives.nut" import close_ingame_gui, get_cur_unit_weapon_preset, is_respawn_screen, get_player_unit_name
from "%scripts/dagui_library.nut" import *
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getWeaponShortTypeFromWpName } = require("%scripts/weaponry/weaponryDescription.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { get_game_type, get_cur_game_mode_name } = require("mission")
let { get_mission_restore_type, get_pilot_name, is_aircraft_delayed, is_aircraft_active,
  is_aircraft_player, set_tactical_screen_player, get_player_group } = require("guiMission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { locCurrentMissionName } = require("%scripts/missions/missionsUtils.nut")
let { isInFlight } = require("gameplayBinding")
let { registerRespondent } = require("scriptRespondent")

function gui_start_tactical_map(params = {}) {
  let { forceTacticalControl = false } = params
  handlersManager.loadHandler(gui_handlers.TacticalMap, { forceTacticalControl })
}

function gui_start_tactical_map_tc(_) {
  gui_start_tactical_map({ forceTacticalControl = true })
}

eventbus_subscribe("gui_start_tactical_map", gui_start_tactical_map)
eventbus_subscribe("gui_start_tactical_map_tc", gui_start_tactical_map_tc)

  gui_handlers.TacticalMap <- class (gui_handlers.BaseGuiHandlerWT) {
    sceneBlkName = "%gui/tacticalMap.blk"
    shouldBlurSceneBg = true
    shouldOpenCenteredToCameraInVr = true
    keepLoaded = true
    wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP |
                           CtrlsInGui.CTRL_ALLOW_MP_STATISTICS |
                           CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
                           CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY

    forceTacticalControl = false

    units = []
    unitsActive = []
    numUnits = 0
    wasPlayer = 0
    focus = -1
    restoreType = ERT_TACTICAL_CONTROL
    isFocusChanged = false
    wasMenuShift = false
    isActiveTactical = false

    function initScreen() {
      this.scene.findObject("update_timer").setUserData(this)

      this.subHandlers.append(
        ::gui_load_mission_objectives(this.scene.findObject("primary_tasks_list"),   false, 1 << OBJECTIVE_TYPE_PRIMARY),
        ::gui_load_mission_objectives(this.scene.findObject("secondary_tasks_list"), false, 1 << OBJECTIVE_TYPE_SECONDARY)
      )

      this.initWnd()
    }

    function initWnd() {
      this.restoreType = get_mission_restore_type();

      if ((this.restoreType != ERT_TACTICAL_CONTROL))
        this.isActiveTactical = false

      this.units = get_player_group()
      this.numUnits = this.units?.len() ?? 0
      log("numUnits = " + this.numUnits)

      this.initData()

  //    scene.findObject("dmg_hud").tag = "" + units[focus]

      local isRespawn = false

      if (this.restoreType == ERT_TACTICAL_CONTROL) {
        for (local i = 0; i < this.numUnits; i++) {
          if (is_aircraft_delayed(this.units[i]))
            continue

          if (is_aircraft_player(this.units[i])) {
            if (! is_aircraft_active(this.units[i]))
              isRespawn = true
            break
          }
        }
        if (isRespawn || this.forceTacticalControl) {
          log("[TMAP] isRespawn = " + isRespawn)
          log("[TMAP] 2 forceTacticalControl = " + this.forceTacticalControl)
          this.isActiveTactical = true
        }
        else
          this.isActiveTactical = false
      }

      this.scene.findObject("objectives_panel").show(!this.isActiveTactical)
      this.scene.findObject("pilots_panel").show(this.isActiveTactical)

      this.updatePlayer()
      this.update(null, 0.03)
      this.updateTitle()

      showObjById("btn_select", this.isActiveTactical, this.scene)
      showObjById("btn_back", true, this.scene)
      showObjById("screen_button_back", useTouchscreen, this.scene)
    }

    function reinitScreen(params = {}) {
      this.setParams(params)
      this.initWnd()
      /*
      initData()
      updatePlayer()
      update(null, 0.03)
      updateTitle()
      */
    }

    function updateTitle() {
      let gt = get_game_type()
      local titleText = locCurrentMissionName()
      if (gt & GT_VERSUS)
        titleText = loc($"multiplayer/{get_cur_game_mode_name()}Mode")

      this.setSceneTitle(titleText, this.scene, "menu-title")
    }

    function update(obj, dt) {
      this.updateTacticalControl(obj, dt)

      if (is_respawn_screen()) {
        this.guiScene.performDelayed({}, function() {
          eventbus_send("gui_start_respawn")
          ::update_gamercards()
        })
      }
    }

    function updateTacticalControl(_obj, _dt) {
      if (this.restoreType != ERT_TACTICAL_CONTROL)
        return;
      if (!this.isActiveTactical)
        return

      if (this.focus >= 0 && this.focus < this.numUnits) {
        let isActive = is_aircraft_active(this.units[this.focus])
        if (!isActive) {
          this.scene.findObject("objectives_panel").show(false)
          this.scene.findObject("pilots_panel").show(true)

          this.onFocusDown(null)
        }
        if (!is_aircraft_active(this.units[this.focus])) {
          log("still no active aircraft");
          this.guiScene.performDelayed(this, function() {
            this.doClose()
          })
          return;
        }
        if (!isActive) {
          set_tactical_screen_player(this.units[this.focus], false)
          this.guiScene.performDelayed(this, function() {
            this.doClose()
          })
        }
      }


      for (local i = 0; i < this.numUnits; i++) {
        if (is_aircraft_delayed(this.units[i])) {
          log("unit " + i + " is delayed");
          continue;
        }

        let isActive = is_aircraft_active(this.units[i]);
        if (isActive != this.unitsActive[i]) {
          let trObj = this.scene.findObject("pilot_name" + i)
          trObj.enable = isActive ? "yes" : "no";
          trObj.inactive = isActive ? null : "yes"
          this.unitsActive[i] = isActive;
        }
      }
    }

    function initData() {
      if (this.restoreType != ERT_TACTICAL_CONTROL)
        return;
      this.fillPilotsTable()

      for (local i = 0; i < this.numUnits; i++) {
        if (is_aircraft_delayed(this.units[i]))
          continue

        if (is_aircraft_player(this.units[i])) {
          this.wasPlayer = i
          this.focus = this.wasPlayer
          break
        }
      }

      for (local i = 0; i < this.numUnits; i++)
        this.unitsActive.append(true)

      for (local i = 0; i < this.numUnits; i++) {
        if (is_aircraft_delayed(this.units[i]))
          continue;

        local pilotFullName = ""
        let pilotId = get_pilot_name(this.units[i], i)
        if (pilotId != "") {
          if (get_game_type() & GT_COOPERATIVE) {
            pilotFullName = pilotId; //player nick
          }
          else {
            pilotFullName = loc(pilotId)
          }
        }
        else
          pilotFullName = "Pilot " + (i + 1).tostring()

        log("pilot " + i + " name = " + pilotFullName + " (id = " + pilotId.tostring() + ")")

        this.scene.findObject("pilot_text" + i).setValue(pilotFullName)
        let objTr = this.scene.findObject("pilot_name" + i)
        let isActive = is_aircraft_active(this.units[i])

        objTr.mainPlayer = (this.wasPlayer == i) ? "yes" : "no"
        objTr.enable = isActive ? "yes" : "no"
        objTr.inactive = isActive ? null : "yes"
        objTr.selected = (this.focus == i) ? "yes" : "no"
      }

      if (this.numUnits > 0)
        setMousePointerInitialPos(this.scene.findObject("pilots_list").getChild(this.wasPlayer))
    }

    function fillPilotsTable() {
      local data = ""
      for (local k = 0; k < this.numUnits; k++)
        data += format("tr { id:t = 'pilot_name%d'; css-hier-invalidate:t='all'; td { text { id:t = 'pilot_text%d'; }}}",
                       k, k)

      let pilotsObj = this.scene.findObject("pilots_list")
      this.guiScene.replaceContentFromText(pilotsObj, data, data.len(), this)
      pilotsObj.baseRow = (this.numUnits < 13) ? "yes" : "rows16"
    }

    function updatePlayer() {
      if (!checkObj(this.scene))
        return

      if (this.numUnits > 0 && (this.restoreType == ERT_TACTICAL_CONTROL) && this.isActiveTactical) {
        if (!(this.focus in this.units))
          this.focus = 0

        set_tactical_screen_player(this.units[this.focus], true)

        for (local i = 0; i < this.numUnits; i++) {
          if (is_aircraft_delayed(this.units[i]))
            continue

  //        if ((focus < 0) && is_aircraft_player(units[i]))
  //          focus = i

          this.scene.findObject("pilot_name" + i).selected = (this.focus == i) ? "yes" : "no"
        }

    //    scene.findObject("dmg_hud").tag = "" + units[focus]
        let obj = this.scene.findObject("pilot_name" + this.focus)
        if (obj)
          obj.scrollToView()
      }

      let obj = this.scene.findObject("pilot_aircraft")
      if (obj) {
        let fm = get_player_unit_name()
        let unit = getAircraftByName(fm)
        local text = getUnitName(fm)
        if (unit?.isAir() || unit?.isHelicopter?())
          text += loc("ui/colon") + getWeaponShortTypeFromWpName(get_cur_unit_weapon_preset(), fm)
        obj.setValue(text)
      }
    }

    function onFocusDown(_obj) {
      if (this.restoreType != ERT_TACTICAL_CONTROL)
        return
      if (!this.isActiveTactical)
        return

      let wasFocus = this.focus
      this.focus++
      if (this.focus >= this.numUnits)
        this.focus = 0;

      local cur = this.focus
      for (local i = 0; i < this.numUnits; i++) {
        let isActive = is_aircraft_active(this.units[cur])
        let isDelayed = is_aircraft_delayed(this.units[cur])
        if (isActive && !isDelayed)
          break

        cur++
        if (cur >= this.numUnits)
          cur = 0
      }

      this.focus = cur
      if (wasFocus != this.focus) {
        this.updatePlayer()
      }
      else
        log("onFocusDown - can't find aircraft that is active and not delayed")
    }

    function onFocusUp(_obj) {
      if (this.restoreType != ERT_TACTICAL_CONTROL)
        return
      if (!this.isActiveTactical)
        return

      let wasFocus = this.focus
      this.focus--
      if (this.focus < 0)
        this.focus = this.numUnits - 1;

      local cur = this.focus
      for (local i = 0; i < this.numUnits; i++) {
        let isActive = is_aircraft_active(this.units[cur])
        let isDelayed = is_aircraft_delayed(this.units[cur])

        if (isActive && !isDelayed)
          break

        cur--
        if (cur < 0)
          cur = this.numUnits - 1
      }

      this.focus = cur

      if (wasFocus != this.focus)
        this.updatePlayer()
    }

    function onPilotsSelect(_obj) {
      if (this.restoreType != ERT_TACTICAL_CONTROL || !this.isActiveTactical)
        return

      let newFocus = this.scene.findObject("pilots_list").getValue()
      if (this.focus == newFocus)
        return

      this.focus = this.scene.findObject("pilots_list").getValue()
      this.updatePlayer()
    }

    function doClose() {
      let closeFn = base.goBack
      this.guiScene.performDelayed(this, function() {
        if (isInFlight()) {
          close_ingame_gui()
          if (this.isSceneActive())
            closeFn()
        }
      })
    }

    goBack  = @() this.doClose()

    function onStart(obj) {
      if ((this.restoreType != ERT_TACTICAL_CONTROL) || !this.isActiveTactical)
        return this.doClose()

      this.updateTacticalControl(obj, 0.0)
      if (this.focus in this.units)
        set_tactical_screen_player(this.units[this.focus], false)
      this.doClose()
    }

    function onPilotsDblClick(obj) {
      if (showConsoleButtons.value)
        return

      this.onStart(obj)
    }
  }

  ::addHideToObjStringById <- function addHideToObjStringById(data, objId) {
    let pos = data.indexof("id:t = '" + objId + "';")
    if (pos)
      return data.slice(0, pos) + "display:t='hide'; " + data.slice(pos)
    return data
  }

  registerRespondent("is_tactical_map_active", function is_tactical_map_active() {
    if (!("TacticalMap" in gui_handlers))
      return false
    let curHandler = handlersManager.getActiveBaseHandler()
    return curHandler != null &&  (curHandler instanceof gui_handlers.TacticalMap ||
      curHandler instanceof gui_handlers.ArtilleryMap || curHandler instanceof gui_handlers.RespawnHandler)
  })

return {
  gui_start_tactical_map
}
