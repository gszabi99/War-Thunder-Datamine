let { getWeaponShortTypeFromWpName } = require("%scripts/weaponry/weaponryDescription.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")

::gui_start_tactical_map <- function gui_start_tactical_map(use_tactical_control = false)
{
  ::tactical_map_handler = ::handlersManager.loadHandler(::gui_handlers.TacticalMap,
                           { forceTacticalControl = use_tactical_control })
}

::gui_start_tactical_map_tc <- function gui_start_tactical_map_tc()
{
  gui_start_tactical_map(true);
}

::gui_handlers.TacticalMap <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/tacticalMap.blk"
  shouldBlurSceneBg = true
  shouldFadeSceneInVr = true
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
  restoreType = ::ERT_TACTICAL_CONTROL
  isFocusChanged = false
  wasMenuShift = false
  isActiveTactical = false

  function initScreen()
  {
    scene.findObject("update_timer").setUserData(this)

    subHandlers.append(
      ::gui_load_mission_objectives(scene.findObject("primary_tasks_list"),   false, 1 << ::OBJECTIVE_TYPE_PRIMARY),
      ::gui_load_mission_objectives(scene.findObject("secondary_tasks_list"), false, 1 << ::OBJECTIVE_TYPE_SECONDARY)
    )

    initWnd()
  }

  function initWnd()
  {
    restoreType = ::get_mission_restore_type();

    if ((restoreType != ::ERT_TACTICAL_CONTROL))
      isActiveTactical = false

    let playerArr = [1]
    numUnits = ::get_player_group(units, playerArr)
    dagor.debug("numUnits = "+numUnits)

    initData()

//    scene.findObject("dmg_hud").tag = "" + units[focus]

    local isRespawn = false

    if (restoreType == ::ERT_TACTICAL_CONTROL)
    {
      for (local i = 0; i < numUnits; i++)
      {
        if (::is_aircraft_delayed(units[i]))
          continue

        if (::is_aircraft_player(units[i]))
        {
          if (! ::is_aircraft_active(units[i]))
            isRespawn = true
          break
        }
      }
      if (isRespawn || forceTacticalControl)
      {
        dagor.debug("[TMAP] isRespawn = "+isRespawn)
        dagor.debug("[TMAP] 2 forceTacticalControl = " + forceTacticalControl)
        isActiveTactical = true
      }
      else
        isActiveTactical = false
    }

    scene.findObject("objectives_panel").show(!isActiveTactical)
    scene.findObject("pilots_panel").show(isActiveTactical)

    updatePlayer()
    update(null, 0.03)
    updateTitle()

    showSceneBtn("btn_select", isActiveTactical)
    showSceneBtn("btn_back", true)
    showSceneBtn("screen_button_back", useTouchscreen)
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initWnd()
    /*
    initData()
    updatePlayer()
    update(null, 0.03)
    updateTitle()
    */
  }

  function updateTitle()
  {
    let gt = ::get_game_type()
    local titleText = ::loc_current_mission_name()
    if (gt & ::GT_VERSUS)
      titleText = ::loc("multiplayer/" + ::get_cur_game_mode_name() + "Mode")

    setSceneTitle(titleText, scene, "menu-title")
  }

  function update(obj, dt)
  {
    updateTacticalControl(obj, dt)

    if (::is_respawn_screen())
    {
      guiScene.performDelayed({}, function() {
        ::gui_start_respawn()
        ::update_gamercards()
      })
    }
  }

  function updateTacticalControl(obj, dt)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return;
    if (!isActiveTactical)
      return

    if (focus >= 0 && focus < numUnits)
    {
      let isActive = ::is_aircraft_active(units[focus])
      if (!isActive)
      {
        scene.findObject("objectives_panel").show(false)
        scene.findObject("pilots_panel").show(true)

        onFocusDown(null)
      }
      if (!::is_aircraft_active(units[focus]))
      {
        dagor.debug("still no active aircraft");
        guiScene.performDelayed(this, function()
        {
          doClose()
        })
        return;
      }
      if (!isActive)
      {
        ::set_tactical_screen_player(units[focus], false)
        guiScene.performDelayed(this, function()
        {
          doClose()
        })
      }
    }


    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
      {
        dagor.debug("unit "+i+" is delayed");
        continue;
      }

      let isActive = ::is_aircraft_active(units[i]);
      if (isActive != unitsActive[i])
      {
        let trObj = scene.findObject("pilot_name" + i)
        trObj.enable = isActive ? "yes" : "no";
        trObj.inactive = isActive ? null : "yes"
        unitsActive[i] = isActive;
      }
    }
  }

  function initData()
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return;
    fillPilotsTable()

    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
        continue

      if (::is_aircraft_player(units[i]))
      {
        wasPlayer = i
        focus = wasPlayer
        break
      }
    }

    for (local i = 0; i < numUnits; i++)
      unitsActive.append(true)

    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
        continue;

      local pilotFullName = ""
      let pilotId = ::get_pilot_name(units[i], i)
      if (pilotId != "")
      {
        if (::get_game_type() & ::GT_COOPERATIVE)
        {
          pilotFullName = pilotId; //player nick
        }
        else
        {
          pilotFullName = ::loc(pilotId)
        }
      }
      else
        pilotFullName = "Pilot "+(i+1).tostring()

      dagor.debug("pilot "+i+" name = "+pilotFullName+" (id = " + pilotId.tostring()+")")

      scene.findObject("pilot_text" + i).setValue(pilotFullName)
      let objTr = scene.findObject("pilot_name" + i)
      let isActive = ::is_aircraft_active(units[i])

      objTr.mainPlayer = (wasPlayer == i)? "yes" : "no"
      objTr.enable = isActive ? "yes" : "no"
      objTr.inactive = isActive ? null : "yes"
      objTr.selected = (focus == i)? "yes" : "no"
    }

    if (numUnits > 0)
      setMousePointerInitialPos(scene.findObject("pilots_list").getChild(wasPlayer))
  }

  function fillPilotsTable()
  {
    local data = ""
    for(local k = 0; k < numUnits; k++)
      data += format("tr { id:t = 'pilot_name%d'; css-hier-invalidate:t='all'; td { text { id:t = 'pilot_text%d'; }}}",
                     k, k)

    let pilotsObj = scene.findObject("pilots_list")
    guiScene.replaceContentFromText(pilotsObj, data, data.len(), this)
    pilotsObj.baseRow = (numUnits < 13)? "yes" : "rows16"
  }

  function updatePlayer()
  {
    if (!::checkObj(scene))
      return

    if (numUnits && (restoreType == ::ERT_TACTICAL_CONTROL) && isActiveTactical)
    {
      if (!(focus in units))
        focus = 0

      ::set_tactical_screen_player(units[focus], true)

      for (local i = 0; i < numUnits; i++)
      {
        if (::is_aircraft_delayed(units[i]))
          continue

//        if ((focus < 0) && ::is_aircraft_player(units[i]))
//          focus = i

        scene.findObject("pilot_name" + i).selected = (focus == i) ? "yes" : "no"
      }

  //    scene.findObject("dmg_hud").tag = "" + units[focus]
      let obj = scene.findObject("pilot_name" + focus)
      if (obj)
        obj.scrollToView()
    }

    let obj = scene.findObject("pilot_aircraft")
    if (obj)
    {
      let fm = ::get_player_unit_name()
      let unit = ::getAircraftByName(fm)
      local text = ::getUnitName(fm)
      if (unit?.isAir() || unit?.isHelicopter?())
        text += ::loc("ui/colon") + getWeaponShortTypeFromWpName(::get_cur_unit_weapon_preset(), fm)
      obj.setValue(text)
    }
  }

  function onFocusDown(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return
    if (!isActiveTactical)
      return

    let wasFocus = focus
    focus++
    if (focus >= numUnits)
      focus = 0;

    local cur = focus
    for (local i = 0; i < numUnits; i++)
    {
      let isActive = ::is_aircraft_active(units[cur])
      let isDelayed = ::is_aircraft_delayed(units[cur])
      if (isActive && !isDelayed)
        break

      cur++
      if (cur >= numUnits)
        cur = 0
    }

    focus = cur
    if (wasFocus != focus)
    {
      updatePlayer()
    }
    else
      dagor.debug("onFocusDown - can't find aircraft that is active and not delayed")
  }

  function onFocusUp(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return
    if (!isActiveTactical)
      return

    let wasFocus = focus
    focus--
    if (focus < 0)
      focus = numUnits - 1;

    local cur = focus
    for (local i = 0; i < numUnits; i++)
    {
      let isActive = ::is_aircraft_active(units[cur])
      let isDelayed = ::is_aircraft_delayed(units[cur])

      if (isActive && !isDelayed)
        break

      cur--
      if (cur < 0)
        cur = numUnits - 1
    }

    focus = cur

    if (wasFocus != focus)
      updatePlayer()
  }

  function onPilotsSelect(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL || !isActiveTactical)
      return

    let newFocus = scene.findObject("pilots_list").getValue()
    if (focus == newFocus)
      return

    focus = scene.findObject("pilots_list").getValue()
    updatePlayer()
  }

  function doClose()
  {
    let closeFn = base.goBack
    guiScene.performDelayed(this, function()
    {
      if (::is_in_flight())
      {
        ::close_ingame_gui()
        if (isSceneActive())
          closeFn()
      }
    })
  }

  goBack  = @() doClose()

  function onStart(obj)
  {
    if ((restoreType != ::ERT_TACTICAL_CONTROL) || !isActiveTactical)
      return doClose()

    updateTacticalControl(obj, 0.0)
    if (focus in units)
      ::set_tactical_screen_player(units[focus], false)
    doClose()
  }

  function onPilotsDblClick(obj) {
    if (::show_console_buttons)
      return

    onStart(obj)
  }
}

::addHideToObjStringById <- function addHideToObjStringById(data, objId)
{
  let pos = data.indexof("id:t = '" + objId + "';")
  if (pos)
    return data.slice(0, pos) + "display:t='hide'; " + data.slice(pos)
  return data
}

::is_tactical_map_active <- function is_tactical_map_active()
{
  if (!("TacticalMap" in ::gui_handlers))
    return false
  let curHandler = ::handlersManager.getActiveBaseHandler()
  return curHandler != null &&  (curHandler instanceof ::gui_handlers.TacticalMap ||
    curHandler instanceof ::gui_handlers.ArtilleryMap || curHandler instanceof ::gui_handlers.RespawnHandler)
}
