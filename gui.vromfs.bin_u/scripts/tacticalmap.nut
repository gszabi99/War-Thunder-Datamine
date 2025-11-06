from "gameplayBinding" import isInFlight, closeIngameGui
from "guiRespawn" import isRespawnScreen
from "%scripts/dagui_library.nut" import *
let { get_player_unit_name, get_cur_unit_weapon_preset } = require("unit")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getWeaponShortTypeFromWpName } = require("%scripts/weaponry/weaponryDescription.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { get_game_type, get_cur_game_mode_name } = require("mission")
let { get_mission_restore_type, get_pilot_name, is_aircraft_delayed, is_aircraft_active,
  is_aircraft_player, set_tactical_screen_player, get_player_group,
  ERT_TACTICAL_CONTROL, OBJECTIVE_TYPE_PRIMARY, OBJECTIVE_TYPE_SECONDARY } = require("guiMission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { setMissionEnviroment } = require("%scripts/missions/missionsUtils.nut")
let { locCurrentMissionName } = require("%scripts/missions/missionsText.nut")
let { registerRespondent } = require("scriptRespondent")
let { setAllowMoveCenter, isAllowedMoveCenter, setForcedHudType, getCurHudType,
  setPointSettingMode, isPointSettingMode, resetPointOfInterest, isPointOfInterestSet  } = require("guiTacticalMap")
let { hasSightStabilization } = require("vehicleModel")
let { gui_load_mission_objectives } = require("%scripts/misObjectives/misObjectivesView.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")

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
                           CtrlsInGui.CTRL_IN_TACTICAL_MAP |
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

      this.registerSubHandler(gui_load_mission_objectives(this.scene.findObject("primary_tasks_list"),   false, 1 << OBJECTIVE_TYPE_PRIMARY))
      this.registerSubHandler(gui_load_mission_objectives(this.scene.findObject("secondary_tasks_list"), false, 1 << OBJECTIVE_TYPE_SECONDARY))

      this.initWnd()
      ::g_hud_hints_manager.init(this.scene, { paramsToCheck = ["showWithMap"] })
    }

    function isCurUnitAircraft() {
      let unit = getAircraftByName(get_player_unit_name())
      return (unit?.isAir() || unit?.isHelicopter?())
    }

    function initWnd() {
      this.restoreType = get_mission_restore_type();

      if ((this.restoreType != ERT_TACTICAL_CONTROL))
        this.isActiveTactical = false

      this.units = get_player_group()
      this.numUnits = this.units?.len() ?? 0
      log($"numUnits = {this.numUnits}")

      this.initData()

  

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
          log($"[TMAP] isRespawn = {isRespawn}")
          log($"[TMAP] 2 forceTacticalControl = {this.forceTacticalControl}")
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

      showObjById("hint_btn_move_map", !showConsoleButtons.get(), this.scene)
      let isAircraft = this.isCurUnitAircraft()
      let isShowPOiButton = isAircraft && hasSightStabilization()
      let setPointOfInterestObj = showObjById("btn_set_point_of_interest", isShowPOiButton, this.scene)
      if (isShowPOiButton)
        showObjById("hint_btn_set_point_of_interest", !showConsoleButtons.get(), setPointOfInterestObj)

      let isShowSetHudTypeBtn = !isAircraft
      let setHudTypeObj = showObjById("btn_set_hud_type", isShowSetHudTypeBtn, this.scene)
      if (isShowSetHudTypeBtn) {
        let buttonImg = setHudTypeObj.findObject("hud_type_img")
        buttonImg["background-image"] = isAircraft ? "#ui/gameuiskin#objective_tank.svg" : "#ui/gameuiskin#objective_fighter.svg"
        showObjById("hint_btn_set_hud_type", !showConsoleButtons.get(), setHudTypeObj)
      }

      setAllowMoveCenter(false)
      this.resetPointOfInterestMode()
    }

    function reinitScreen(params = {}) {
      this.setParams(params)
      this.initWnd()
      ::g_hud_hints_manager.reinit(this.scene)
      





    }

    function updateTitle() {
      let gt = get_game_type()
      local titleText = locCurrentMissionName()
      if (gt & GT_VERSUS)
        titleText = loc($"multiplayer/{get_cur_game_mode_name()}Mode")

      this.setSceneTitle(titleText, this.scene, "menu-title")
      setMissionEnviroment(this.scene.findObject("conditions_text"))
    }

    function update(obj, dt) {
      this.updateTacticalControl(obj, dt)

      if (isRespawnScreen()) {
        this.guiScene.performDelayed({}, function() {
          eventbus_send("gui_start_respawn")
          updateGamercards()
        })
      }

      let tacticalMapObj = this.scene.findObject("tactical-map")
      tacticalMapObj.cursor =  isAllowedMoveCenter() ? "moveArrowCursor" : isPointSettingMode() ? "pointOfInterest" : "normal"

      let buttonImg = this.scene.findObject("hud_poi_img");
      buttonImg["background-image"] =  isPointOfInterestSet() ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"

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
          log($"unit {i} is delayed");
          continue;
        }

        let isActive = is_aircraft_active(this.units[i]);
        if (isActive != this.unitsActive[i]) {
          let trObj = this.scene.findObject($"pilot_name{i}")
          trObj.enable = isActive ? "yes" : "no";
          trObj.inactive = isActive ? null : "yes"
          this.unitsActive[i] = isActive;
        }
      }
    }

    function resetPointOfInterestMode() {
      setPointSettingMode(false)
      showObjById("POI_resetter", false, this.scene)
      let tacticalMapObj = this.scene.findObject("tactical-map")
      tacticalMapObj.cursor = "normal"
      let buttonImg = this.scene.findObject("hud_poi_img");
      buttonImg["background-image"] =  isPointOfInterestSet() ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"
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
            pilotFullName = pilotId; 
          }
          else {
            pilotFullName = loc(pilotId)
          }
        }
        else
          pilotFullName = $"Pilot {i + 1}"

        log($"pilot {i} name = {pilotFullName} (id = {pilotId})")

        this.scene.findObject($"pilot_text{i}").setValue(pilotFullName)
        let objTr = this.scene.findObject($"pilot_name{i}")
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
        data = "".concat(
          data,
          format("tr { id:t = 'pilot_name%d'; css-hier-invalidate:t='all'; td { text { id:t = 'pilot_text%d'; }}}", k, k)
        )

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

  
  

          this.scene.findObject($"pilot_name{i}").selected = (this.focus == i) ? "yes" : "no"
        }

    
        let obj = this.scene.findObject($"pilot_name{this.focus}")
        if (obj)
          obj.scrollToView()
      }

      let obj = this.scene.findObject("pilot_aircraft")
      if (obj) {
        let fm = get_player_unit_name()
        let unit = getAircraftByName(fm)
        local text = getUnitName(fm)
        if (unit?.isAir() || unit?.isHelicopter?())
          text = "".concat(text, loc("ui/colon"), getWeaponShortTypeFromWpName(get_cur_unit_weapon_preset(), fm))
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
          closeIngameGui()
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
      if (showConsoleButtons.get())
        return

      this.onStart(obj)
    }

    function onMoveMapActivate() {
      setAllowMoveCenter(!isAllowedMoveCenter())
      let tacticalMapObj = this.scene.findObject("tactical-map")
      tacticalMapObj.cursor =  isAllowedMoveCenter() ? "moveArrowCursor" : "normal"
   }

   function onForcedSetHudType(obj) {
    local curHudType = getCurHudType()
    if (curHudType == HUD_TYPE_UNKNOWN) {
      curHudType = this.isCurUnitAircraft() ? HUD_TYPE_AIRPLANE : HUD_TYPE_TANK
    }

    let isSwitchToTankHud = curHudType == HUD_TYPE_AIRPLANE
    setForcedHudType(isSwitchToTankHud ? HUD_TYPE_TANK : HUD_TYPE_AIRPLANE)
    obj.findObject("hud_type_img")["background-image"] = isSwitchToTankHud  ? "#ui/gameuiskin#objective_fighter.svg" : "#ui/gameuiskin#objective_tank.svg"
  }

  function onSetPointOfInterest(obj) {
    setAllowMoveCenter(false)
    let buttonImg = obj.findObject("hud_poi_img");
    if (isPointOfInterestSet()) {
      resetPointOfInterest()
      buttonImg["background-image"] = "#ui/gameuiskin#map_interestpoint.svg"
      setPointSettingMode(false)
      showObjById("POI_resetter", false, this.scene)
      return
    }
    let isPointSettingModeOn = !isPointSettingMode()
    setPointSettingMode(isPointSettingModeOn)
    buttonImg["background-image"] = isPointSettingModeOn ? "#ui/gameuiskin#map_interestpoint_delete.svg" : "#ui/gameuiskin#map_interestpoint.svg"
    let tacticalMapObj = this.scene.findObject("tactical-map")
    tacticalMapObj.cursor =  isPointSettingModeOn ? "pointOfInterest" : "normal"
    showObjById("POI_resetter", isPointSettingModeOn, this.scene)
  }

  function onRespawnScreenClick() {
    this.resetPointOfInterestMode()
  }
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
