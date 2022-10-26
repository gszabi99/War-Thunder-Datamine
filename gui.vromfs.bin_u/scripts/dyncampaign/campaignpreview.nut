from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getDynamicResult } = require("%scripts/debriefing/debriefingFull.nut")

::gui_start_dynamic_summary <- function gui_start_dynamic_summary()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = false })
}

::gui_start_dynamic_summary_f <- function gui_start_dynamic_summary_f()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = true })
}

::gui_handlers.CampaignPreview <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/dynamicSummary.blk"
  sceneNavBlkName = "%gui/dynamicSummaryNav.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  wndGameMode = GM_DYNAMIC

  isFinal = false
  info = null

  logObj = null
  layout = ""

  loses = ["fighters", "bombers", "tanks", "infantry", "ships", "artillery"]

  isInInfo = false
  logId = 0
  logShowTime = 6
  logHideTime = 0.5
  logTimer = 0
  logLastMission = 0
  loseImages = {
    fighters   = "#ui/gameuiskin#objective_fighter.svg"
    bombers    = "#ui/gameuiskin#objective_bomber.svg"
    tanks      = "#ui/gameuiskin#objective_tank.svg"
    infantry   = "#ui/gameuiskin#objective_troops.png"
    ships      = "#ui/gameuiskin#objective_destroyer.svg"
    artillery  = "#ui/gameuiskin#objective_aa.png"
  }

  function initScreen()
  {
    if (this.guiScene["cutscene_update"])
      this.guiScene["cutscene_update"].setUserData(this)

    this.info = ::DataBlock()
    ::g_map_preview.setSummaryPreview(this.scene.findObject("tactical-map"), this.info, "")

    let l_file = this.info.getStr("layout","")
    let dynLayouts = ::get_dynamic_layouts()
    for (local i = 0; i < dynLayouts.len(); i++)
      if (dynLayouts[i].mis_file == l_file)
      {
        this.layout = dynLayouts[i].name
        if (!this.isFinal)
          this.guiScene["scene-title"].text = loc("dynamic/" + this.layout)
      }
    if (this.isFinal)
      this.guiScene["scene-title"].text = (getDynamicResult() == MISSION_STATUS_SUCCESS) ? loc("DYNAMIC_CAMPAIGN_SUCCESS") : loc("DYNAMIC_CAMPAIGN_FAIL")

    this.guiScene["info-date"].text = loc("date_format",
    {
     year = this.info.getInt("dataYYYY",0),
     day = this.info.getInt("dataDD",0),
     month = loc("sm_month_"+this.info.getInt("dataMM",0).tostring())
    })

    let playerSide = this.info.getInt("playerSide", 1)
    if (playerSide == 2)
    {
      this.guiScene["enemy-icon"]["background-image"] = "#ui/gameuiskin#team_allies_icon.svg"
      this.guiScene["ally-icon"]["background-image"] = "#ui/gameuiskin#team_axis_icon.svg"
    }
    else
    {
      this.guiScene["ally-icon"]["background-image"] = "#ui/gameuiskin#team_allies_icon.svg"
      this.guiScene["enemy-icon"]["background-image"] = "#ui/gameuiskin#team_axis_icon.svg"
    }


//    guiScene["scene-info"]["text"] = "one long line\none long line\none long line"
    let stats = ["wins", "sectors", "bombers", "fighters", "infantry", "tanks", "artillery","ships"]
    let sides = ["ally","enemy"]
    for (local i = 0; i < stats.len(); i++)
    {
      for (local j = 0; j < sides.len(); j++)
      {
        local value = this.info.getInt(sides[j]+"_"+stats[i], 0)
        if (value > 10000)
          value = "" + ((value/1000).tointeger()).tostring() + "K"
        this.guiScene["info-"+stats[i]+j.tostring()].text = value
      }
    }

    this.logObj = []
    for (local i = this.info.blockCount() - 1; i >= 0; i--)
      if (this.info.getBlock(i).getBlockName() == "log")
        this.logObj.append(this.buildLogLine(this.info.getBlock(i)))

    let country = (playerSide == 2) ? this.info.getStr("country_axis","germany") : this.info.getStr("country_allies", "usa")
    //wtf??
    log("2 country = " + country)
    if (country != "")
      this.guiScene["briefing-flag"]["background-image"] = ::get_country_flag_img("bgflag_country_" + country)

    if (this.isFinal)
    {
      ::showBtn("btn_back", false, this.scene)
      setDoubleTextToButton(this.scene, "btn_apply", loc("mainmenu/btnOk"))
    } else
      if (!::first_generation)
        setDoubleTextToButton(this.scene, "btn_apply", loc("mainmenu/btnNext"))

    ::move_mouse_on_obj(this.scene.findObject("btn_apply"))
  }

  function buildLogLine(blk)
  {
    let ret = {}

    if (blk.getStr("sectorName", "").len() > 0)
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s</Color>\n"
                    + "<Color=@blogCommonColor>%s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        loc("dynamic/"+this.layout+"/"+blk.getStr("sectorName","")),
        loc(blk.getStr("description",""))
        )
    }
    else if (blk.getStr("winsCountTextId", "").len() > 0)
    {
      ret.main <- format("<Color=@blogHeaderColor>%s %d</Color>\n",
        loc(blk.getStr("winsCountTextId", "")),
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
        loc(blk.getStr("description","")),
        loc(blk.getStr("reason", ""))
        )
    }
    else if (blk.getInt("enemyStartCount", -1) >= 0)
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s %s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        loc(blk.getStr("description","")),
        loc("dynamic/" + blk.getStr("level","") + "_dynamic")
        )
    }
    else
    {
      ret.main <- format("<Color=@blogDateColor>%02d.%02d.%d</Color> <Color=@blogHeaderColor>%s</Color>\n",
        blk.getInt("dataDD",1),
        blk.getInt("dataMM",1),
        blk.getInt("dataYYYY",1941),
        loc(blk.getStr("description",""))
        )
    }

    ret.ally_loses <- "";
    ret.enemy_loses <- "";
    if (blk.getBool("showLoss", false))
    {
      for (local i = 0; i < this.loses.len(); i++)
        ret.ally_loses += this.getLosesBlk(this.loses[i], blk.getInt("ally_destroyed_"+this.loses[i], 0), i < (this.loses.len()-1))

      for (local i = 0; i < this.loses.len(); i++)
        ret.enemy_loses += this.getLosesBlk(this.loses[i], blk.getInt("enemy_destroyed_"+this.loses[i], 0), i < (this.loses.len()-1))
    }

    let misNum = blk.getInt("missionsPlayed", 0)
    if (misNum > this.logLastMission)
    {
      this.logLastMission = misNum
      this.logId = 0;
    }

    ret.victory <- blk.getBool("isVictory", false)
    ret.sideIcon <- blk.getInt("owner", 1)?  //1 - allies, 2 - axis
                      "#ui/gameuiskin#team_allies_icon.svg": "#ui/gameuiskin#team_axis_icon.svg"

    ret.showInSmallLog <- blk.getBool("showInSmallLog", false)

    return ret
  }

  function getLosesBlk(name, count, comma = false)
  {
    local data = ""
    if (name in this.loseImages)
      data += format("logIcon{ background-image:t='%s'} ", this.loseImages[name])
    data += format("text{ text:t='%s'; text-align:t='left'} ",
              count.tostring() + (comma? "," : ""))
    return data
  }

  function onUpdate(_obj, dt)
  {
    if (this.logObj.len() > 0)
    {
      this.logTimer -= dt
      if (this.logTimer < -this.logHideTime)
      {
        this.showLog(this.logId)
        this.logTimer = this.logShowTime

        for (local cnt = 0; cnt <= this.logObj.len() ; cnt++)
        {
          this.logId = (this.logId + 1) % this.logObj.len();
          if (this.logObj[this.logId].showInSmallLog)
            break;
        }
      }
      else if (this.logTimer <= 0)
        this.showLog(-1)
    }
  }

  function showLog(id)
  {
    let show = (id >= 0 && this.logObj.len() > id && this.logObj[id].showInSmallLog)
    if (show)
      this.guiScene["scene-info"].setValue(this.logObj[id].main)
    this.guiScene["scene-info"].animShow = show? "show" : "hide"
  }

  function onSelect(_obj)
  {
    let gm = ::get_game_mode()
    if (gm == GM_DYNAMIC)
    {
      if (::is_dynamic_won_by_player())
      {
        local wonCampaign = ""
        let l_file = this.info.getStr("layout","")
        let dynLayouts = ::get_dynamic_layouts()
        for (local i = 0; i < dynLayouts.len(); i++)
          if (dynLayouts[i].mis_file == l_file)
          {
            wonCampaign = dynLayouts[i].name
          }

        if (wonCampaign != "")
          ::add_won_mission("dynamic", wonCampaign)
      }

      if (::SessionLobby.isInRoom())
        if (!::SessionLobby.isRoomOwner && !this.isFinal && !::first_generation)
        {
          this.msgBox("not_available", loc("msgbox/wait_for_squad_leader"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
          return;
        }
    }

    if (this.isFinal)
      this.goForward(::gui_start_dynamic_results)
    else
      ::gui_start_mislist(true, null, { owner = this })
  }
  function onBack(_obj)
  {
    if (::first_generation)
      this.goForward(::gui_start_mainmenu)
    else
    {
      this.msgBox("question_quit_mission", loc("flightmenu/questionQuitCampaign"),
      [
        ["yes", function()
        {
          let gt = ::get_game_type()
          if (gt & GT_COOPERATIVE)
            ::destroy_session_scripted()
          this.goForward(::gui_start_mainmenu)
        }],
        ["no", function() {}]
      ], "no")
    }
  }

  function showNav(is_show)
  {
    ::showBtn("btn_apply", is_show)
    ::showBtn("btn_back", is_show && !this.isFinal)
    ::showBtn("btn_battlelog", is_show)
    this.guiScene["scene-title"].show(is_show)
  }

  function infoBox(data, title = "")
  {
    let rootNode = ""

    let handlerClass = class {
      function goBack(_obj)
      {
        let delayedAction = (@(handler, guiScene, infoBoxObject) function() {
          guiScene.destroyElement(infoBoxObject)
          handler.isInInfo = false
          handler.showNav(true)
        })(this.handler, this.guiScene, this.infoBoxObject)
        this.guiScene.performDelayed(this, delayedAction)
      }
      guiScene = null
      infoBoxObject = null
      handler = null
    }

    let handlerObj = handlerClass()
    let infobox = this.guiScene.loadModal(rootNode, "%gui/optionInfoBox.blk", "InfoBox", handlerObj)
    handlerObj.guiScene = this.guiScene
    handlerObj.infoBoxObject = infobox
    handlerObj.handler = this

    this.setSceneTitle(title, infobox, "menu-title")
    this.guiScene.replaceContentFromText(infobox.findObject("info-area"), data, data.len(), handlerObj)
  }

  function onInfo(_obj)
  {
    if (this.isInInfo)
      return

    local data = ""
    let logTextsToSet = {}

    for (local i = (this.logObj.len() - 1); i >= 0; i--)
    {
      data += format("textareaNoTab { id:t='%s'; width:t='pw'; sideLogIcon { background-image:t='%s'} } \n",
                "logtext_" + i, this.logObj[i].sideIcon)
      logTextsToSet["logtext_" + i] <- this.logObj[i].main

      if (this.logObj[i].ally_loses.len() > 0)
      {
        data += format("tdiv { text{ id:t='%s'; text-align:t='left'} %s } \n",
                  "ally_loses_" + i, this.logObj[i].ally_loses);
        logTextsToSet["ally_loses_" + i] <- loc("log/losses_ally") + ": "
      }

      if (this.logObj[i].enemy_loses.len() > 0)
      {
        data += format("tdiv { margin-bottom:t='0.03sh'; text{ id:t='%s'; text-align:t='left'} %s } \n",
                  "enemy_loses_" + i, this.logObj[i].enemy_loses);
        logTextsToSet["enemy_loses_" + i] <- loc("log/losses_enemy") + ": "
      } else
        data += "tdiv { margin-bottom:t='0.03sh';} \n";
    }

    let title = loc("mainmenu/btnBattlelog")

    this.infoBox(data, title)
    this.isInInfo = true
    this.showNav(false)

    foreach(name, text in logTextsToSet)
      this.guiScene[name].setValue(text)
/*
    this.msgBox("info", data,
      [
        ["ok", function() {} ]
      ], "ok") */
  }
}