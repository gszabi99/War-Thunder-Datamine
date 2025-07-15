from "%scripts/dagui_natives.nut" import clan_get_admin_editor_mode, clan_get_my_clan_id, clan_validate_membership_requirements
from "%scripts/dagui_library.nut" import *

let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { format } = require("string")
let clanMembershipAcceptance = require("%scripts/clans/clanMembershipAcceptance.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { debug_dump_stack } = require("dagor.debug")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK,
  USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK, USEROPT_CLAN_REQUIREMENTS_MIN_BLUEWATER_SHIP_RANK,
  USEROPT_CLAN_REQUIREMENTS_MIN_COASTAL_SHIP_RANK, USEROPT_CLAN_REQUIREMENTS_ALL_MIN_RANKS,
  USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES, USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES,
  USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES, USEROPT_CLAN_REQUIREMENTS_AUTO_ACCEPT_MEMBERSHIP
} = require("%scripts/options/optionsExtNames.nut")
let { addTask } = require("%scripts/tasker.nut")
let { create_options_container, get_option } = require("%scripts/options/optionsExt.nut")
let { clan_request_set_membership_requirements } = require("%scripts/clans/clanRequests.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")
let { checkUGCAllowed } = require("%scripts/clans/clanTextInfo.nut")

gui_handlers.clanChangeMembershipReqWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL;
  sceneBlkName = "%gui/clans/clanChangeMembershipReqWnd.blk";
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  owner = null;
  clanData = null;

  optionItems = [
    [USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK,  "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_BLUEWATER_SHIP_RANK, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_COASTAL_SHIP_RANK, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_ALL_MIN_RANKS, "switchbox"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES, "spinner"],
    [USEROPT_CLAN_REQUIREMENTS_AUTO_ACCEPT_MEMBERSHIP, "switchbox"]
  ]

  minRankCondTypeObject = null
  autoAcceptMembershipObject = null

  
  
  
  
  
  
  
  
  
  
  
  

  ugcAllowed = false

  function initScreen() {
    let captured = this
    checkUGCAllowed(function(is_ugc_allowed) {
      captured.ugcAllowed = is_ugc_allowed
      captured.actualInitScreen()
    })
  }

  function actualInitScreen() {
    if (!this.clanData)
      return this.goBack()
    this.reinitScreen()
  }

  function reinitScreen() {
    let container = create_options_container("optionslist", this.optionItems, true, 0.5, false)
    this.guiScene.replaceContentFromText(this.scene.findObject("contentBody"), container.tbl, container.tbl.len(), this)

    local option = get_option(USEROPT_CLAN_REQUIREMENTS_ALL_MIN_RANKS)
    this.minRankCondTypeObject = this.scene.findObject(option.id)

    option = get_option(USEROPT_CLAN_REQUIREMENTS_AUTO_ACCEPT_MEMBERSHIP)
    this.autoAcceptMembershipObject = this.scene.findObject(option.id)
    this.autoAcceptMembershipObject.setValue(this.clanData.autoAcceptMembership)

    this.loadRequirementsBattles(this.clanData.membershipRequirements)
    this.loadRequirementsRanks(this.clanData.membershipRequirements)

    this.recalcMinRankCondTypeSwitchState()

    let isMembershipAccptanceEnabled = clanMembershipAcceptance.getValue(this.clanData)
    this.scene.findObject("membership_acceptance_checkbox").setValue(isMembershipAccptanceEnabled)
  }

  function loadRequirementsBattles(rawClanMemberRequirementsBlk) {
    foreach (diff in g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let option = get_option(diff.clanReqOption)
        let modeName = diff.getEgdName(false)
        local battlesRequired = 0;
        let req = rawClanMemberRequirementsBlk.getBlockByName(option.id)
        if (req  &&  (req.type == "battles")  &&  (req.difficulty == modeName))
          battlesRequired = req.getInt("count", 0)

        let optIdx = option.values.indexof(battlesRequired) ?? 0
        this.scene.findObject(option.id).setValue(optIdx)
      }
  }

  function loadRequirementsRanks(rawClanMemberRequirementsBlk) {
    let rawRanksCond = rawClanMemberRequirementsBlk.getBlockByName("ranks") || DataBlock()
    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable())
        continue

      let obj = this.scene.findObject($"rankReq{unitType.name}")
      if (!checkObj(obj))
        continue

      local ranksRequired = 0
      let req = rawRanksCond.getBlockByName($"rank_{unitType.name}")
      if (req?.type == "rank" && req?.unitType == unitType.name)
        ranksRequired = req.getInt("rank", 0)

      obj.setValue(ranksRequired)
    }

    this.minRankCondTypeObject.setValue(rawRanksCond?.type != "or")
  }

  function getNonEmptyRankReqCount() {
    local nonEmptyRankReqCount = 0
    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable())
        continue

      let obj = this.scene.findObject($"rankReq{unitType.name}")
      if (!checkObj(obj))
        continue

      let ranksRequired = obj.getValue()
      if (ranksRequired > 0)
        nonEmptyRankReqCount++
    }

    return nonEmptyRankReqCount
  }

  function getNonEmptyBattlesReqCount() {
    local nonEmptyBattlesReqCount = 0
    foreach (diff in g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let option = get_option(diff.clanReqOption)
        let optIdx = this.scene.findObject(option.id).getValue()
        if (optIdx > 0)
          nonEmptyBattlesReqCount++
      }

    return nonEmptyBattlesReqCount
  }

  function onRankReqChange() {
    this.recalcMinRankCondTypeSwitchState()
  }

  function recalcMinRankCondTypeSwitchState() {
    if (this.getNonEmptyRankReqCount() > 1) {
      this.minRankCondTypeObject.enable(true)
    }
    else {
      this.minRankCondTypeObject.setValue(1) 
      this.minRankCondTypeObject.enable(false)
    }
  }

  function onApply() {
    let newRequirements = DataBlock()
    let gotChanges = this.fillRequirements(newRequirements)

    if (gotChanges)
      this.sendRequirementsToChar(newRequirements, this.autoAcceptMembershipObject.getValue())
    else
      this.goBack()
  }

  function fillRequirements(newRequirements) {
    this.appendRequirementsRanks(newRequirements)
    this.appendRequirementsBattles(newRequirements)

    if (newRequirements.blockCount() != 0)
      newRequirements.setStr("type", "and")

    if (u.isEqual(this.clanData.membershipRequirements, newRequirements)) {
      let autoAccept = this.autoAcceptMembershipObject.getValue()
      if (this.clanData.autoAcceptMembership == autoAccept)
        return false;
    }

    let validateResult = clan_validate_membership_requirements(newRequirements)
    if (validateResult == "")
      return true;

    let errText = format("ERROR: [ClanMembershipReq] validation error '%s'", validateResult)
    debug_dump_stack()
    script_net_assert_once("bad clan requirements", errText)
    return false
  }


  function appendRequirementsRanks(newRequirements) {
    let rankCondType = this.minRankCondTypeObject.getValue() ? "and" : "or"
    local ranksSubBlk = null

    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable())
        continue

      let obj = this.scene.findObject($"rankReq{unitType.name}")
      if (!checkObj(obj))
        continue

      let rankVal = obj.getValue()
      if (rankVal > 0) {
        if (!ranksSubBlk) {
          ranksSubBlk = newRequirements.addNewBlock("ranks")
          ranksSubBlk.setStr("type", rankCondType)
        }

        let condBlk = ranksSubBlk.addNewBlock($"rank_{unitType.name}")
        condBlk.setStr("type", "rank")
        condBlk.setInt("rank", rankVal)
        condBlk.setInt("count", 1)
        condBlk.setStr("unitType", unitType.name)
      }
    }
  }


  function appendRequirementsBattles(newRequirements) {
    foreach (diff in g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let option = get_option(diff.clanReqOption)
        let modeName = diff.getEgdName(false);
        let battleReqVal = option.values[this.scene.findObject(option.id).getValue()];

        if (battleReqVal > 0) {
          let condBlk = newRequirements.addNewBlock(option.id)
          condBlk.setStr("type", "battles")
          condBlk.setStr("difficulty", modeName)
          condBlk.setInt("count", battleReqVal)
        }
      }
  }


  function sendRequirementsToChar(newRequirements, autoAccept) {
    let resultCB = Callback( function() {
      this.clanData.membershipRequirements = newRequirements;
      this.clanData.autoAcceptMembership = autoAccept;

      if (clan_get_admin_editor_mode() && this.owner && "reinitClanWindow" in this.owner)
        this.owner.reinitClanWindow()

      broadcastEvent("ClanRquirementsChanged")
      this.goBack()
    }, this)

    let taskId = clan_request_set_membership_requirements(this.clanData.id, newRequirements, autoAccept)

    addTask(taskId, { showProgressBox = true }, resultCB)
  }

  function onMembershipAcceptanceClick(obj) {
    clanMembershipAcceptance.setValue(this.clanData, obj.getValue(), this)
  }

  function onEventClanInfoUpdate(_p) {
    if (this.clanData.id != clan_get_my_clan_id())
      return

    this.clanData = myClanInfo.get()
    if (!this.clanData)
      return this.goBack()

    this.reinitScreen()
  }

  function onEventClanInfoAvailable(p) {
    if (this.clanData.id != p.clanId)
      return

    this.clanData = get_clan_info_table(this.ugcAllowed)
    if (!this.clanData)
      return this.goBack()

    this.reinitScreen()
  }
}
