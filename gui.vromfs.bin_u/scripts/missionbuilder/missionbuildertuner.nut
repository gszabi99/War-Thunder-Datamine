local { getLastWeapon, isWeaponVisible } = require("scripts/weaponry/weaponryInfo.nut")
local { getWeaponInfoText,
        getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")
local { AMMO,
        getAmmoCost,
        getAmmoAmountData } = require("scripts/weaponry/ammoInfo.nut")

::gui_start_builder_tuner <- function gui_start_builder_tuner()
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilderTuner)
}

class ::gui_handlers.MissionBuilderTuner extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"

  noChoice = false
  unitsBlk = null
  listA = null
  listW = null
  listS = null
  listC = null

  wtags = null

  function initScreen()
  {
    setSceneTitle(::loc("mainmenu/btnDynamicPreview"), scene, "menu-title")

    unitsBlk = DataBlock()
    ::dynamic_get_units(::mission_settings.missionFull, unitsBlk)

    local list = createOptions()
    local listObj = scene.findObject("optionslist")
    guiScene.replaceContentFromText(listObj, list, list.len(), this)

    for (local i = 1; i < listW.len(); i++)
      listObj.findObject(i.tostring() + "_w").setValue(0)

    //if (noChoice)
    //  applyOptions()

    //mission preview
    ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), ::mission_settings.missionFull)

    local country = ::getCountryByAircraftName(::mission_settings.mission.getStr("player_class", ""))
    dagor.debug("1 player_class = "+::mission_settings.mission.getStr("player_class", "") + "; country = " + country)
    if (country != "")
      scene.findObject("briefing-flag")["background-image"] = ::get_country_flag_img("bgflag_" + country)

    local misObj = ""
    misObj = ::loc(format("mb/%s/objective", ::mission_settings.mission.getStr("name", "")), "")
    scene.findObject("mission-objectives").setValue(misObj)
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene.findObject("tuner_options")
  }

  function buildAircraftOptions(aircrafts, curA, isPlayer)
  {
    local ret = ""
    for (local i = 0; i < aircrafts.len(); i++)
      ret += build_option_blk("#" + aircrafts[i] + "_shop", image_for_air(aircrafts[i]), curA == aircrafts[i])
    listA.append(aircrafts)
    return ret
  }

  function buildWeaponOptions(aircraft, curW, weapTags)
  {
    local weapons = getWeaponsList(aircraft, false, weapTags, false, false) //check_aircraft_purchased=false
    if (weapons.values.len() == 0)
    {
      dagor.debug("bomber without bombs: "+aircraft)
      weapons = getWeaponsList(aircraft, false, null, false, false) //check_aircraft_purchased=false
    }

    local ret = ""
    for (local i = 0; i < weapons.values.len(); i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + ::locOrStrip(weapons.items[i].text) + "'} " +
        "tooltip:t = '" + ::locOrStrip(weapons.items[i].tooltip) + "' " +
        (curW == weapons.values[i] ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} " //-10%sh
      )
    }
    listW.append(weapons.values)
    return ret
  }

  function buildSkinOptions(aircraft, curS)
  {
    local skins = ::g_decorator.getSkinsOption(aircraft)

    local ret = ""
    for (local i = 0; i < skins.values.len(); i++)
    {
      ret += (
        "option { " +
          "optiontext { text:t = '" + ::locOrStrip(skins.items[i].text) + "'; " +
            skins.items[i].textStyle +
          "} " +
        (curS == skins.values[i] ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} " //-10%sh
      )
    }
    listS.append(skins.values)
    return ret
  }

  function buildFuelOptions(desc)
  {
    local ret = ""
    for (local i = 0; i < desc.values.len(); i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + ::locOrStrip(desc.items[i]) + "'} " +
        (desc.values[i] == 50 ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} "  //-10%sh
      )
    }
    return ret
  }

  function buildCountOptions(minCount, maxCount, curC)
  {
    local ret = ""
    local list = []
    for (local i = minCount; i <= maxCount; i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + i.tostring() + "'} " +
        (curC == i ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} "  //-10%sh
      )
      list.append(i)
    }
    listC.append(list)
    return ret
  }

  function createOptions()
  {
    listA = []
    listW = []
    listS = []
    listC = []
    wtags = []
    noChoice = true

    local data = ""

    local wLeft  = "45%pw"
    local wRight = "55%pw"
    local selectedRow = 0
    local separator = ""

    local isFreeFlight = ::mission_settings.missionFull.mission_settings.mission.isFreeFlight;

    for (local i = 0; i < unitsBlk.blockCount(); i++)
    {
      local armada = unitsBlk.getBlock(i)

      local name = armada.getStr("name","")
      local aircraft = armada.getStr("unit_class", "");
      local weapon = armada.getStr("weapons", "");
      local skin = armada.getStr("skin", "");
      local count = armada.getInt("count", 4);
      local army = armada.getInt("army", 1); //1-ally, 2-enemy
      local isBomber = armada.getBool("mustBeBomber", false);
      local isFighter = armada.getBool("mustBeFighter", false);
      local isAssault = armada.getBool("mustBeAssault", false);
      local isPlayer = armada.getBool("isPlayer", false);
      local minCount = armada.getInt("minCount", 1);
      local maxCount = armada.getInt("maxCount", 4);
      local excludeTag = isFreeFlight ? "not_in_free_flight" : "not_in_dynamic_campaign";

      if (isPlayer)
      {
        local airName = ::show_aircraft.name
        ::mission_settings.mission.player_class = airName
        armada.unit_class = airName
        armada.weapons = getLastWeapon(airName)
        armada.skin = ::g_decorator.getLastSkin(airName)
        listA.append([armada.unit_class])
        listW.append([armada.weapons])
        listS.append([armada.skin])
        listC.append([4])
        wtags.append([])
        continue
      }

      if ((name == "") || (aircraft == ""))
        break;

      local adesc = armada.description
      local fmTags = adesc % "needFmTag"
      local weapTags = adesc % "weaponOrTag"

      local aircrafts = []

      foreach(unit in ::all_units)
      {
        if (isInArray(excludeTag, unit.tags))
          continue
        if (isInArray("aux", unit.tags))
          continue
        local tagsOk = true
        for (local k = 0; k < fmTags.len(); k++)
          if (!isInArray(fmTags[k], unit.tags))
          {
            tagsOk = false
            break
          }
        if (!tagsOk)
          continue
        if (getWeaponsList(unit.name, false, weapTags, false, false).values.len() < 1) //check_aircraft_purchased=false
          continue
        if (isPlayer)
        {
//          if (!::is_unlocked_scripted(::UNLOCKABLE_AIRCRAFT, unit.name))
//            continue
          if (!unit.isUsable())
            continue
        }
        aircrafts.append(unit.name)
      }

      // make sure that aircraft exists in aircrafts array
      local found = false
      foreach (k in aircrafts)
        if (k == aircraft)
        {
          found = true;
          break
        }
      if (!found)
        aircrafts.append(aircraft)

      aircrafts.sort(function(a,b)
      {
        if(a > b) return 1
        else if(a<b) return -1
        return 0;
      })

      //aircraft type
      local trId = (army == unitsBlk.getInt("playerSide", 1)) ? "ally" : "enemy"
      if (isPlayer)
        trId = "player"
      if (isBomber)
        trId += "Bomber"
      else if (isFighter)
        trId += "Fighter"
      else if (isAssault)
        trId += "Assault"

      local trIdN = isPlayer ? trId : trId+i.tostring()

      dagor.debug("building "+trIdN)

      local rowData = ""
      local elemText = ""
      local optlist = ""

      wtags.append(weapTags)

      // Aircraft
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_a" + "'; text:t ='" +
        "#options/" + trId
        + "'; } }"
      optlist = buildAircraftOptions(aircrafts, aircraft, isPlayer)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_a'; " + "on_select:t = '" + "onChangeAircraft" + "'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + separator + " }"
      if (!isPlayer) data += "tr { width:t='pw'; iconType:t='aircraft'; id:t = '" + trIdN + "_a_tr" + "'; " + rowData + " } "

      // Weapon
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_w" + "'; text:t ='" +
        "#options/secondary_weapons"
        + "'; } }"
      optlist = buildWeaponOptions(aircraft, weapon, weapTags)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_w'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer) data += "tr { width:t='pw'; id:t = '" + trIdN + "_w_tr" + "'; " + rowData + " } "

      // Skin
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_s" + "'; text:t ='" +
        "#options/skin"
        + "'; } }"
      optlist = buildSkinOptions(aircraft, skin)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_s'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer) data += "tr { width:t='pw'; id:t = '" + trIdN + "_s_tr" + "'; " + rowData + " } "

      // Count
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_c" + "'; text:t ='" +
        "#options/count"
        + "'; } }"
      optlist = buildCountOptions(minCount, maxCount, count)
      elemText = "ComboBox { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_c'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer)
      {
        data += "tr { width:t='pw'; id:t = '" + trIdN + "_c_tr" + "'; " + rowData + " } "
        noChoice = false
      }

      separator = "trSeparator{}"
    }

    local resTbl = @"
      table
      {
        id:t= 'tuner_options';
        pos:t = '(pw-w)/2,(ph-h)/2';
        width:t='pw';
        position:t = 'absolute';
        class:t = 'optionsTable';
        baseRow:t = 'yes';
        focus:t = 'yes';
        behavior:t = 'OptionsNavigator';
        cur_col:t='" + selectedRow + @"';
        cur_row:t='0';
        cur_min:t='1';
        num_rows:t='-1';
        "
        + data + @"
      }
      "
    ;

    return resTbl
  }

  function onChangeAircraft(obj)
  {
    for (local i = 0; i < listA.len(); i++)
    {
      local airId = i.tostring() + "_a"
      if (obj?.id == airId)
      {
        local aircraft = listA[i][scene.findObject(airId).getValue()]

        local optlist = ""

        local weapons = getWeaponsList(aircraft, false, wtags[i], false, false) //check_aircraft_purchased=false
        if (weapons.values.len() == 0)
        {
          dagor.debug("bomber without bombs: "+aircraft)
          weapons = getWeaponsList(aircraft, false, null, false, false) //check_aircraft_purchased=false
        }

        for (local j = 0; j < weapons.values.len(); j++)
        {
          optlist += (
            "option { " +
            "optiontext { text:t = '" + ::locOrStrip(weapons.items[j].text) + "'} " +
            "tooltip:t = '" + ::locOrStrip(weapons.items[j].tooltip) + "' " +
            ((j==0) ? "selected:t = 'yes'; " : "") +
            " max-width:t='p.p.w-10%sh'; pare-text:t='yes'} "
          )
        }
        listW[i] = weapons.values

/*
        local newSpinner = "ComboBox"+" { size:t='pw, ph'; " +
          "id:t = '" + i.tostring() + "_w'; " + optlist
          + " }" */
        local newSpinner = optlist

        local weapObj = scene.findObject(i.tostring() + "_w")
        guiScene.replaceContentFromText(weapObj, newSpinner, newSpinner.len(), this)
        weapObj.setValue(0)

        local skins = ::g_decorator.getSkinsOption(aircraft)

        optlist = ""
        for (local j = 0; j < skins.values.len(); j++)
        {
          optlist += (
            "option { " +
              "optiontext { text:t = '" + ::locOrStrip(skins.items[j].text) + "'; " +
                skins.items[j].textStyle +
              "} " +
            ((j==0) ? "selected:t = 'yes'; " : "") +
            " max-width:t='p.p.w-10%sh'; pare-text:t='yes'} "
          )
        }
        listS[i] = skins.values

/*        newSpinner = "spinnerListBox"+" { size:t='pw, ph'; " +
          "id:t = '" + i.tostring() + "_s'; " + optlist
          + " }"*/
        newSpinner = optlist

        local skinObj = scene.findObject(i.tostring() + "_s")
        guiScene.replaceContentFromText(skinObj, newSpinner, newSpinner.len(), this)
        skinObj.setValue(0)
        return
      }
    }
  }

  function onApply(obj)
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    for (local i = 0; i < listA.len(); i++)
    {
      local airId = i.tostring() + "_a"
      local weapId = i.tostring() + "_w"
      local skinId = i.tostring() + "_s"
      local countId = i.tostring() + "_c"

      local aircraft = ""
      local weapon = ""
      local skin = ""
      local count = 4
      if (i == 0)
      {
        count = 4
        continue;
      }
      else
      {
        aircraft = listA[i][scene.findObject(airId).getValue()]
        weapon = listW[i][scene.findObject(weapId).getValue()]
        skin = listS[i][scene.findObject(skinId).getValue()]
        count = listC[i][scene.findObject(countId).getValue()]
      }

      local armada = unitsBlk.getBlock(i)
      armada.setStr("unit_class", aircraft);
      armada.setStr("weapons", weapon);
      armada.setStr("skin", skin);
      armada.setInt("count", count);
    }
    ::mission_settings.mission.setInt("_gameMode", ::GM_BUILDER)
    local fuelObj = scene.findObject("fuel_amount")
    if (fuelObj)
    {
      local am = ::get_option(::USEROPT_LOAD_FUEL_AMOUNT).values[fuelObj.getValue()]
      ::set_gui_option(::USEROPT_LOAD_FUEL_AMOUNT, am)
    }

    ::dynamic_set_units(::mission_settings.missionFull, unitsBlk)
    ::select_mission_full(::mission_settings.mission,
       ::mission_settings.missionFull)

    ::set_context_to_player("difficulty", ::get_mission_difficulty())

    local appFunc = function()
    {
      if (::SessionLobby.isInRoom())
        goForward(::gui_start_mp_lobby);
      else if (::mission_settings.coop)
      {
        // ???
      }
      else
        goForward(::gui_start_flight)
    }

    if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(appFunc, this)
    else
      appFunc()
  }

  function onBack(obj)
  {
    goBack()
  }

  function getWeaponsList(aircraft, need_cost, weapTags, only_bought=false, check_aircraft_purchased=true)
  {
    local descr = {}
    descr.items <- []
    descr.values <- []
    descr.cost <- []
    descr.costGold <- []
    descr.hints <- []

    local unit = ::getAircraftByName(aircraft)
    if (!unit)
      return descr

    local optionSeparator = ", "
    local hintSeparator = "\n"

    foreach(weapNo, weapon in unit.weapons)
    {
      local weaponName = weapon.name
      if (!isWeaponVisible(unit, weapon, only_bought, weapTags))
        continue

      local cost = getAmmoCost(unit, weaponName, AMMO.WEAPON)
      descr.cost.append(cost.wp)
      descr.costGold.append(cost.gold)
      descr.values.append(weaponName)

      local costText = (need_cost && cost > ::zero_money)? "(" + cost.getUncoloredWpText() + ") " : ""
      local amountText = check_aircraft_purchased && ::is_game_mode_with_spendable_weapons() ?
        getAmmoAmountData(unit, weaponName, AMMO.WEAPON).text : "";

      local tooltip = costText + getWeaponInfoText(unit, { isPrimary = false, weaponPreset = weapNo, newLine = hintSeparator })
        + amountText

      descr.items.append({
        text = costText + getWeaponNameText(unit, false, weapNo, optionSeparator) + amountText
        tooltip = tooltip
      })
      descr.hints.append(tooltip)
    }

    return descr
  }
}