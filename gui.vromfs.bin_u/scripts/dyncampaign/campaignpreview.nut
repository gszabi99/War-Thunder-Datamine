::gui_start_dynamic_summary <- function gui_start_dynamic_summary()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = false })
}

::gui_start_dynamic_summary_f <- function gui_start_dynamic_summary_f()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = true })
}

class ::gui_handlers.CampaignPreview extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/dynamicSummary.blk"
  sceneNavBlkName = "gui/dynamicSummaryNav.blk"

  wndGameMode = ::GM_DYNAMIC

  isFinal = false
  info = null

  log = null
  layout = ""

  loses = ["fighters", "bombers", "tanks", "infantry", "ships", "artillery"]

  isInInfo = false
  logId = 0
  logShowTime = 6
  logHideTime = 0.5
  logTimer = 0
  logLastMission = 0
  loseImages = {
    fighters   = "#ui/gameuiskin#objective_fighter"
    bombers    = "#ui/gameuiskin#objective_bomber"
    tanks      = "#ui/gameuiskin#objective_tank"
    infantry   = "#ui/gameuiskin#objective_troops"
    ships      = "#ui/gameuiskin#objective_destroyer"
    artillery  = "#ui/gameuiskin#objective_aa"
  }

  function initScreen()
  {
    if (guiScene["cutscene_update"])
      guiScene["cutscene_update"].setUserData(this)

    info = DataBlock()
    ::g_map_preview.setSummaryPreview(scene.findObject("tactical-map"), info, "")

    local l_file = info.getStr("layout","")
    local dynLayouts = ::get_dynamic_layouts()
    for (local i = 0; i < dynLayouts.len(); i++)
      if (dynLayouts[i].mis_file == l_file)
      {
        layout = dynLayouts[i].name
        if (!isFinal)
          guiScene["scene-title"].text = ::loc("dynamic/" + layout)
      }
    if (isFinal)
      guiScene["scene-title"].text = (::dynamic_result == ::MISSION_STATUS_SUCCESS) ? ::loc("DYNAMIC_CAMPAIGN_SUCCESS") : ::loc("DYNAMIC_CAMPAIGN_FAIL")

    guiScene["info-date"].text = ::loc("date_format",
    {
     year = info.getInt("dataYYYY",0),
     day = info.getInt("dataDD",0),
     month = ::loc("sm_month_"+info.getInt("dataMM",0).tostring())
    })

    local playerSide = info.getInt("playerSide", 1)
    if (playerSide == 2)
    {
      guiScene["enemy-icon"]["background-image"] = "#ui/gameuiskin#team_allies_icon"
      guiScene["ally-icon"]["background-image"] = "#ui/gameuiskin#team_axis_icon"
    }
    else
    {
      guiScene["ally-icon"]["background-image"] = "#ui/gameuiskin#team_allies_icon"
      guiScene["enemy-icon"]["background-image"] = "#ui/gameuiskin#team_axis_icon"
    }


//    guiScene["scene-info"]["text"] = "one long line\none long line\none long line"
    local stats = ["wins", "sectors", "bombers", "fighters", "infantry", "tanks", "artillery","ships"]
    local sides = ["ally","enemy"]
    for (local i = 0; i < stats.len(); i++)
    {
      for (local j = 0; j < sides.len(); j++)
      {
        local value = info.getInt(sides[j]+"_"+stats[i], 0)
        if (value > 10000)
          value = "" + ((value/1000).tointeger()).tostring() + "K"
        guiScene["info-"+stats[i]+j.tostring()].text = value
      }
    }

    log = []
    for (local i = info.blockCount() - 1; i >= 0; i--)
      if (info.getBlock(i).getBlockName() == "log")
        log.append(buildLogLine(info.getBlock(i)))

    local country = (playerSide == 2) ? info.getStr("country_axis","germany") : info.getStr("country_allies", "usa")
    //wtf??
    dagor.debug("2 country = " + country)
    if (country != "")
      guiScene["briefing-flag"]["background-image"] = ::get_country_flag_img("bgflag_country_" + country)

    if (isFinal)
    {
      ::showBtn("btn_back", false, scene)
      ::setDoubleTextToButton(scene, "btn_apply", ::loc("mainmenu/btnOk"))
    } else
      if (!::first_generation)
        ::setDoubleTextToButton(scene, "btn_apply", ::loc("mainmenu/btnNext"))
  }

  function buildLogLine(blk)
  {
    local ret = {}

    if (blk.getStr("sectorName", "").len() > 0)
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s</Color>\n"
                    + "<Color=@blogCommonColor>%s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        ::loc("dynamic/"+layout+"/"+blk.getStr("sectorName","")),
        ::loc(blk.getStr("description",""))
        )
    }
    else if (blk.getStr("winsCountTextId", "").len() > 0)
    {
      ret.main <- format("<Color=@blogHeaderColor>%s %d</Color>\n",
        ::loc(blk.getStr("winsCountTextId", "")),
        blk.getInt("num", 1)
        );
    }
    else if (blk.getStr("reason", "").len() > 0)
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s</Color>\n"
                    + "<Color=@blogCommonColor>%s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        ::loc(blk.getStr("description","")),
        ::loc(blk.getStr("reason", ""))
        )
    }
    else if (blk.getInt("enemyStartCount", -1) >= 0)
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s %s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        ::loc(blk.getStr("description","")),
        ::loc("dynamic/" + blk.getStr("level","") + "_dynamic")
        )
    }
    else
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        ::loc(blk.getStr("description",""))
        )
    }

    ret.ally_loses <- "";
    ret.enemy_loses <- "";
    if (blk.getBool("showLoss", false))
    {
      for (local i = 0; i < loses.len(); i++)
        ret.ally_loses += getLosesBlk(loses[i], blk.getInt("ally_destroyed_"+loses[i], 0), i < (loses.len()-1))

      for (local i = 0; i < loses.len(); i++)
        ret.enemy_loses += getLosesBlk(loses[i], blk.getInt("enemy_destroyed_"+loses[i], 0), i < (loses.len()-1))
    }

    local misNum = blk.getInt("missionsPlayed", 0)
    if (misNum > logLastMission)
    {
      logLastMission = misNum
      logId = 0;
    }

    ret.victory <- blk.getBool("isVictory", false)
    ret.sideIcon <- blk.getInt("owner", 1)?  //1 - allies, 2 - axis
                      "#ui/gameuiskin#team_allies_icon": "#ui/gameuiskin#team_axis_icon"

    ret.showInSmallLog <- blk.getBool("showInSmallLog", false)

    return ret
  }

  function getLosesBlk(name, count, comma = false)
  {
    local data = ""
    if (name in loseImages)
      data += format("logIcon{ background-image:t='%s'} ", loseImages[name])
    data += format("text{ text:t='%s'; text-align:t='left'} ",
              count.tostring() + (comma? "," : ""))
    return data
  }

  function onUpdate(obj, dt)
  {
    if (log.len() > 0)
    {
      logTimer -= dt
      if (logTimer < -logHideTime)
      {
        showLog(logId)
        logTimer = logShowTime

        for (local cnt = 0; cnt <= log.len() ; cnt++)
        {
          logId = (logId + 1) % log.len();
          if (log[logId].showInSmallLog)
            break;
        }
      }
      else if (logTimer <= 0)
        showLog(-1)
    }
  }

  function showLog(id)
  {
    local show = (id >= 0 && log.len() > id && log[id].showInSmallLog)
    if (show)
      guiScene["scene-info"].setValue(log[id].main)
    guiScene["scene-info"].animShow = show? "show" : "hide"
  }

  function onSelect(obj)
  {
    local gm = ::get_game_mode()
    if (gm == ::GM_DYNAMIC)
    {
      if (::is_dynamic_won_by_player())
      {
        local wonCampaign = ""
        local l_file = info.getStr("layout","")
        local dynLayouts = ::get_dynamic_layouts()
        for (local i = 0; i < dynLayouts.len(); i++)
          if (dynLayouts[i].mis_file == l_file)
          {
            wonCampaign = dynLayouts[i].name
          }

        if (wonCampaign != "")
          ::add_won_mission("dynamic", wonCampaign)
      }

      if (::SessionLobby.isInRoom())
        if (!::SessionLobby.isRoomOwner && !isFinal && !::first_generation)
        {
          msgBox("not_available", ::loc("msgbox/wait_for_squad_leader"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
          return;
        }
    }

    if (isFinal)
      goForward(::gui_start_dynamic_results)
    else
      ::gui_start_mislist(true, null, { owner = this })
  }
  function onBack(obj)
  {
    if (::first_generation)
      goForward(::gui_start_mainmenu)
    else
    {
      msgBox("question_quit_mission", ::loc("flightmenu/questionQuitCampaign"),
      [
        ["yes", function()
        {
          local gt = ::get_game_type()
          if (gt & ::GT_COOPERATIVE)
            ::destroy_session_scripted()
          goForward(::gui_start_mainmenu)
        }],
        ["no", function() {}]
      ], "no")
    }
  }

  function showNav(is_show)
  {
    showBtn("btn_apply", is_show)
    showBtn("btn_back", is_show && !isFinal)
    showBtn("btn_battlelog", is_show)
    guiScene["scene-title"].show(is_show)
  }

  function infoBox(data, title = "")
  {
    local rootNode = ""

    local handlerClass = class {
      function goBack(obj)
      {
        local delayedAction = (@(handler, guiScene, infoBoxObject) function() {
          guiScene.destroyElement(infoBoxObject)
          handler.isInInfo = false
          handler.showNav(true)
        })(handler, guiScene, infoBoxObject)
        guiScene.performDelayed(this, delayedAction)
      }
      guiScene = null
      infoBoxObject = null
      handler = null
    }

    local handlerObj = handlerClass()
    local infobox = guiScene.loadModal(rootNode, "gui/optionInfoBox.blk", "InfoBox", handlerObj)
    handlerObj.guiScene = guiScene
    handlerObj.infoBoxObject = infobox
    handlerObj.handler = this

    setSceneTitle(title, infobox, "menu-title")
    guiScene.replaceContentFromText(infobox.findObject("info-area"), data, data.len(), handlerObj)
  }

  function onInfo(obj)
  {
    if (isInInfo)
      return

    local data = ""
    local logTextsToSet = {}

    for (local i = (log.len() - 1); i >= 0; i--)
    {
      data += format("textareaNoTab { id:t='%s'; width:t='pw'; sideLogIcon { background-image:t='%s'} } \n",
                "logtext_" + i, log[i].sideIcon)
      logTextsToSet["logtext_" + i] <- log[i].main

      if (log[i].ally_loses.len() > 0)
      {
        data += format("tdiv { text{ id:t='%s'; text-align:t='left'} %s } \n",
                  "ally_loses_" + i, log[i].ally_loses);
        logTextsToSet["ally_loses_" + i] <- ::loc("log/losses_ally") + ": "
      }

      if (log[i].enemy_loses.len() > 0)
      {
        data += format("tdiv { margin-bottom:t='0.03sh'; text{ id:t='%s'; text-align:t='left'} %s } \n",
                  "enemy_loses_" + i, log[i].enemy_loses);
        logTextsToSet["enemy_loses_" + i] <- ::loc("log/losses_enemy") + ": "
      } else
        data += "tdiv { margin-bottom:t='0.03sh';} \n";
    }

    local title = ::loc("mainmenu/btnBattlelog")

    infoBox(data, title)
    isInInfo = true
    showNav(false)

    foreach(name, text in logTextsToSet)
      guiScene[name].setValue(text)
/*
    msgBox("info", data,
      [
        ["ok", function() {} ]
      ], "ok") */
  }
}