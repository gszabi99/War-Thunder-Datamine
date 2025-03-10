from "%scripts/dagui_natives.nut" import utf8_strlen
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import fakeBullets_prefix

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")
let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent, add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { hasXInputDevice, emulateShortcut } = require("controls")
let { format } = require("string")
let { debug_dump_stack } = require("dagor.debug")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file(v))
let { isFakeBullet, getBulletsSetData } = require("%scripts/weaponry/bulletsInfo.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { LONG_ACTIONBAR_TEXT_LEN, getActionItemAmountText, getActionItemModificationName,
  getActionItemStatus } = require("%scripts/hud/hudActionBarInfo.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getWheelBarItems, activateActionBarAction, getActionBarUnitName } = require("hudActionBar")
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_EXTINGUISHER, EII_ROCKET, EII_FORCED_GUN,
  EII_GUIDANCE_MODE, EII_SELECT_SPECIAL_WEAPON, EII_GRENADE } = require("hudActionBarConst")
let { arrangeStreakWheelActions } = require("%scripts/hud/hudActionBarStreakWheel.nut")
let { is_replay_playing } = require("replays")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE, hudTypeByHudUnitType } = require("%scripts/hud/hudUnitType.nut")
let { actionBarItems, updateActionBar } = require("%scripts/hud/actionBarState.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { get_game_type, get_mission_time } = require("mission")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_SHOW_ACTION_BAR
} = require("%scripts/options/optionsExtNames.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { closeCurVoicemenu } = require("%scripts/wheelmenu/voiceMessages.nut")
let { guiStartWheelmenu, closeCurWheelmenu } = require("%scripts/wheelmenu/wheelmenu.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { openHudAirWeaponSelector, isVisualHudAirWeaponSelectorOpened } = require("%scripts/hud/hudAirWeaponSelector.nut")
let { getExtraActionItemsView } = require("%scripts/hud/hudActionBarExtraActions.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")

local sectorAngle1PID = dagui_propid_add_name_id("sector-angle-1")

let notAvailableColdownParams = { degree = 0, incFactor = 0 }

function activateShortcutActionBarAction(action) {
  let { shortcutIdx } = action
  if (shortcutIdx != -1) {
    activateActionBarAction(action.shortcutIdx)
    return
  }
  let shortcut = g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
  if (shortcut == null)
    return
  toggleShortcut(shortcut)
  closeCurWheelmenu()
}

function needFullUpdate(item, prevItem, hudUnitType) {
  return item.id != prevItem.id
    || (item.type != prevItem.type
        && g_hud_action_bar_type.getByActionItem(item).getShortcut(item, hudUnitType)
          != g_hud_action_bar_type.getByActionItem(prevItem).getShortcut(prevItem, hudUnitType))
    || (item?.isStreakEx && item.count < 0 && prevItem.count >= 0)
    || ((item.type == EII_BULLET || item.type == EII_FORCED_GUN)
        && item?.modificationName != prevItem?.modificationName)
    || ((item.type == EII_ROCKET || item.type == EII_GRENADE)
        && item?.bulletName != prevItem?.bulletName)
    || ((item.type == EII_SELECT_SPECIAL_WEAPON) && item?.bulletName != prevItem?.bulletName)
}

const ACTION_ID_PREFIX = "action_bar_item_"
let getActionBarObjId = @(itemId) $"{ACTION_ID_PREFIX}{itemId}"

const SECOND_ACTION_ID_PREFIX = "second_action_bar_item_"
let getSecondActionBarObjId = @(itemId) $"{SECOND_ACTION_ID_PREFIX}{itemId}"

const COLLAPSE_ACTION_BAR_SH_ID = "ID_COLLAPSE_ACTION_BAR"
const SECOND_ACTIONS_MENU_LIFETIME = 15

enum ActionBarVsisbility {
  COLLAPSED,
  EXPANDED,
  HIDDEN
}

local isCollapseBtnHidden = false

function getCollapseShText() {
  let shType = g_shortcut_type.getShortcutTypeByShortcutId(COLLAPSE_ACTION_BAR_SH_ID)
  return shType.getFirstInput(COLLAPSE_ACTION_BAR_SH_ID)
}

function hasCollapseShortcut() {
  let shType = g_shortcut_type.getShortcutTypeByShortcutId(COLLAPSE_ACTION_BAR_SH_ID)
  return shType.isAssigned(COLLAPSE_ACTION_BAR_SH_ID)
}

function getVisibilityStateProfilePath() {
  let hudType = hudTypeByHudUnitType?[getHudUnitType()]
  if (hudType == null)
    return null
  return $"actionBar/isCollapsed/{hudType}"
}

let class ActionBar {
  actionItems             = null
  guiScene                = null
  scene                   = null

  canControl              = true
  useWheelmenu            = false
  killStreaksActions      = null
  killStreaksActionsOrdered = null
  weaponActions           = null

  artillery_target_mode = false

  curActionBarUnitName = null

  isFootballMission = false

  cooldownTimers = null

  isCollapsed = false
  isVisible = false
  hasXInputSh = false
  closeSecondActionsTimer = null

  currentActionWithMenu = null
  extraActionsCount = 0

  getActionBarVisibility = @() isCollapseBtnHidden ? ActionBarVsisbility.HIDDEN
    : this.isCollapsed ? ActionBarVsisbility.COLLAPSED
    : ActionBarVsisbility.EXPANDED

  constructor(nestObj) {
    if (!checkObj(nestObj))
      return
    this.scene     = nestObj
    this.guiScene  = nestObj.getScene()
    this.actionItems = []
    this.killStreaksActions = []
    this.weaponActions = []
    this.cooldownTimers = []

    this.canControl = !::isPlayerDedicatedSpectator() && !is_replay_playing()

    this.isFootballMission = (get_game_type() & GT_FOOTBALL) != 0

    let savedVisibilityPath = getVisibilityStateProfilePath()
    if (isProfileReceived.get() && savedVisibilityPath != null) {
      let savedVisibility = loadLocalByAccount(savedVisibilityPath, ActionBarVsisbility.EXPANDED)
      this.isCollapsed = savedVisibility != ActionBarVsisbility.EXPANDED
      updateExtWatched({ isActionBarCollapseBtnHidden = savedVisibility == ActionBarVsisbility.HIDDEN })
    }

    this.updateVisibility()

    g_hud_event_manager.subscribe("ToggleKillStreakWheel", function (eventData) {
      if ("open" in eventData)
        this.toggleKillStreakWheel(eventData.open)
    }, this)
    g_hud_event_manager.subscribe("ToggleSelectWeaponWheel", function (eventData) {
      if ("open" in eventData)
        this.toggleSelectWeaponWheel(eventData.open)
    }, this)
    g_hud_event_manager.subscribe("LiveStatsVisibilityToggled", function (_eventData) {
      this.updateVisibility()
    }, this)
    g_hud_event_manager.subscribe("LocalPlayerAlive", function (_data) {
      updateActionBar()
    }, this)
    add_event_listener("ChangedShowActionBar", function (_eventData) {
      this.updateVisibility()
    }, this)

    this.updateParams()
    updateActionBar()
    this.scene.setValue(stashBhvValueConfig([{
      watch = actionBarItems
      updateFunc = Callback(@(_obj, actionItems) this.updateActionBarItems(actionItems), this) 
    }]))
  }

  isCollapsable = @() this.canControl && ((this.actionItems.len() + this.extraActionsCount) > 0) && hasCollapseShortcut()

  function collapse() {
    if (!this.isValid())
      return

    if (!this.isCollapsable())
      return

    this.isCollapsed = !this.isCollapsed
    if (!this.isCollapsed)
      isCollapseBtnHidden = false

    if (isProfileReceived.get())
      saveLocalByAccount(getVisibilityStateProfilePath(), this.getActionBarVisibility())

    if (!this.isCollapsed)
      updateActionBar()

    this.scene.findObject("actions_nest").anim = this.isCollapsed ? "hide" : "show"
    eventbus_send("setIsActionBarCollapsed", this.isCollapsed)
  }

  getTextShHeight = @() to_pixels("@hudActionBarTextShHight")
  getXInputShHeight = @() to_pixels("0.036@shHud")

  function getActionBarAABB() {
    if (!this.isValid())
      return null

    let size = this.scene.findObject("action_bar").getSize()
    if (size[0] < 0)
      return null 

    let shHeight = this.hasXInputSh ? this.getXInputShHeight() : this.getTextShHeight()
    let pos = this.scene.getPosRC()
    pos[1] -= shHeight
    size[1] += shHeight
    return { pos, size }
  }

  function getState() {
    if (!this.isValid())
      return null

    let { pos = null, size = null } = this.getActionBarAABB()
    let isCollapsable = this.isCollapsable()
    return {
      isCollapsable
      isCollapsed = this.isCollapsed
      isVisible = this.isVisible
      pos
      size
      shortcutText = getCollapseShText().getTextShort()
    }
  }

  function reinit() {
    this.updateParams()
    updateActionBar()
    this.fill()
  }

  function updateParams() {
    this.useWheelmenu = hasXInputDevice()
  }

  function isValid() {
    return checkObj(this.scene)
  }

  function getActionBarUnit() {
    return getAircraftByName(getActionBarUnitName())
  }

  function fill() {
    this.extraActionsCount = 0
    this.flushCooldownTimers()
    if (!checkObj(this.scene))
      return

    this.curActionBarUnitName = getActionBarUnitName()
    let unit = this.getActionBarUnit()
    let view = {
      items = this.actionItems.map((@(a, nestIndex) this.buildItemView(a, nestIndex, true)).bindenv(this))
      extraItems = getExtraActionItemsView(unit)
    }
    this.extraActionsCount = view.extraItems?.len() ?? 0

    let partails = {
      items           = loadTemplateText("%gui/hud/actionBarItem.tpl")
      extraItems      = loadTemplateText("%gui/hud/actionBarItem.tpl")
      textShortcut    = this.canControl ? loadTemplateText("%gui/hud/actionBarItemTextShortcut.tpl")    : ""
      gamepadShortcut = this.canControl ? loadTemplateText("%gui/hud/actionBarItemGamepadShortcut.tpl") : ""
    }

    local newActionWithMenu = null
    foreach (idx, item in this.actionItems) {
      if (item?.isWaitSelectSecondAction)
        newActionWithMenu = item
      let cooldownTimeout = (item?.cooldownEndTime ?? 0) - get_mission_time()
      if (cooldownTimeout > 0)
        this.enableBarItemAfterCooldown(idx, cooldownTimeout)
    }

    let blk = handyman.renderCached(("%gui/hud/actionBar.tpl"), view, partails)
    this.guiScene.replaceContentFromText(this.scene.findObject("actions_nest"), blk, blk.len(), this)
    this.scene.findObject("action_bar").setUserData(this)

    broadcastEvent("HudActionbarInited", { actionBarItemsAmount = this.actionItems.len() + this.extraActionsCount })

    this.hasXInputSh = view.items.findindex(@(item) item.showShortcut && item.isXinput) != null
    let shHeight = this.hasXInputSh ? this.getXInputShHeight() : this.getTextShHeight()
    let animObj = this.scene.findObject("actions_nest")
    animObj["top-end"] = to_pixels("@hudActionBarItemSize") + shHeight
    let isShow = !this.isCollapsable() || !this.isCollapsed
    animObj.anim = isShow ? "show" : "hide"
    animObj["_transp-timer"] = isShow ? "1" : "0"
    animObj["_pos-timer"] = isShow ? "0" : "1"

    this.openSecondActionsMenu(newActionWithMenu)
    get_cur_gui_scene().performDelayed(this, @() eventbus_send("setActionBarState", this.getState()))
  }

  
  function buildItemView(item, nestIndex = -1, needShortcuts = false) {
    let hudUnitType = getHudUnitType()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX

    let actionBarType = g_hud_action_bar_type.getByActionItem(item)
    local shortcutText = ""
    local isXinput = false
    local shortcutId = ""
    local showShortcut = false
    if (needShortcuts && actionBarType.getShortcut(item, hudUnitType)) {
      shortcutId = actionBarType.getVisualShortcut(item, hudUnitType)

      if (this.isFootballMission)
        shortcutId = item?.modificationName == "152mm_football" ? "ID_FIRE_GM"
          : item?.modificationName == "152mm_football_jump" ? "ID_FIRE_GM_MACHINE_GUN"
          : shortcutId

      let shType = g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
      let scInput = shType.getFirstInput(shortcutId)
      shortcutText = scInput.getTextShort()
      isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
      showShortcut = isXinput || shortcutText != ""
    }

    let { isReady } = getActionItemStatus(item)
    let { cooldownEndTime = 0, cooldownTime = 1, inProgressTime = 1, inProgressEndTime = 0,
      blockedCooldownEndTime = 0, blockedCooldownTime = 1, active = true, available = true } = item
    let cooldownParams = available ? this.getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime) : notAvailableColdownParams
    let blockedCooldownParams = this.getWaitGaugeDegreeParams(blockedCooldownEndTime, blockedCooldownTime)
    let progressCooldownParams = this.getWaitGaugeDegreeParams(inProgressEndTime, inProgressTime, !active)
    let viewItem = {
      id               = getActionBarObjId(item.id)
      nestIndex        = nestIndex < 0 ? null : nestIndex.tostring()
      selected         = item.selected ? "yes" : "no"
      active           = item.active ? "yes" : "no"
      enable           = isReady ? "yes" : "no"
      wheelmenuEnabled = isReady || actionBarType.canSwitchAutomaticMode()
      shortcutText     = shortcutText
      isLongScText     = utf8_strlen(shortcutText) >= LONG_ACTIONBAR_TEXT_LEN
      mainShortcutId   = shortcutId
      cancelShortcutId = shortcutId
      isXinput         = showShortcut && isXinput
      showShortcut     = showShortcut
      amount           = getActionItemAmountText(item)
      cooldown                  = cooldownParams.degree
      cooldownIncFactor         = cooldownParams.incFactor
      blockedCooldown           = blockedCooldownParams.degree
      blockedCooldownIncFactor  = blockedCooldownParams.incFactor
      progressCooldown          = progressCooldownParams.degree
      progressCooldownIncFactor = progressCooldownParams.incFactor
      automatic                 = ship && (item?.automatic ?? false)
      hasSecondActionsBtn = item?.additionalBulletInfo != null
      isCloseSecondActionsBtn = item?.isWaitSelectSecondAction ?? false
    }

    let unit = this.getActionBarUnit()
    let modifName = getActionItemModificationName(item, unit)
    if (modifName) {
      
      if (isFakeBullet(modifName) && !(modifName in unit.bulletsSets))
        getBulletsSetData(unit, fakeBullets_prefix, {})
      let data = getBulletsSetData(unit, modifName)
      viewItem.bullets <- handyman.renderCached("%gui/weaponry/bullets.tpl", getBulletsIconView(data))
      viewItem.tooltipId <- MODIFICATION.getTooltipId(unit.name, modifName, { isInHudActionBar = true })
      viewItem.tooltipDelayed <- !this.canControl
    }
    else if (item.type == EII_ARTILLERY_TARGET) {
      viewItem.activatedShortcutId <- "ID_SHOOT_ARTILLERY"
    }

    if (!modifName && item.type != EII_BULLET && item.type != EII_FORCED_GUN) {
      let killStreakTag = getTblValue("killStreakTag", item)
      let killStreakUnitTag = getTblValue("killStreakUnitTag", item)
      viewItem.icon <- actionBarType.getIcon(item, killStreakUnitTag)
      viewItem.name <- actionBarType.getTitle(item, killStreakTag)
      viewItem.tooltipText <- actionBarType.getTooltipText(item)
    }
    else if (actionBarType.isForWheelMenu())
      viewItem.name <- actionBarType.getTitle(item)

    return viewItem
  }

  function buildSecondItemView(item, itemId) {
    let { cooldownEndTime = 0, cooldownTime = 0, inProgressTime = 1, inProgressEndTime = 0,
      blockedCooldownEndTime = 0, blockedCooldownTime = 1, active = true, available = true } = item
    let cooldownParams = this.getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime)
    let blockedCooldownParams = this.getWaitGaugeDegreeParams(blockedCooldownEndTime, blockedCooldownTime)
    let progressCooldownParams = this.getWaitGaugeDegreeParams(inProgressEndTime, inProgressTime, !active)

    let viewItem = {
      id = getSecondActionBarObjId(itemId)
      selected = item.selected ? "yes" : "no"
      active = item.selected ? "yes" : "no"
      available = available
      enable = item.count > 0
      amount = item.count
      cooldown = cooldownParams.degree
      cooldownIncFactor = cooldownParams.incFactor
      blockedCooldown           = blockedCooldownParams.degree
      blockedCooldownIncFactor  = blockedCooldownParams.incFactor
      progressCooldown          = progressCooldownParams.degree
      progressCooldownIncFactor = progressCooldownParams.incFactor
      inProgressTime = 0.0
      nopadding = "yes"
      countEx = -1
      onClick = "onSecondActionClick"
      broken = false
    }

    let unit = this.getActionBarUnit()
    if (item?.type == EII_BULLET) {
      let data = getBulletsSetData(unit, item.modificationName)
      viewItem.bullets <- handyman.renderCached("%gui/weaponry/bullets.tpl", getBulletsIconView(data))
      viewItem.tooltipId <- MODIFICATION.getTooltipId(unit.name, item.modificationName, { isInHudActionBar = true })
    } else if (item?.type != null && item.type != EII_BULLET && item.type != EII_FORCED_GUN) {
      let actionBarType = g_hud_action_bar_type.getByActionItem(item)
      let killStreakTag = getTblValue("killStreakTag", item)
      let killStreakUnitTag = getTblValue("killStreakUnitTag", item)
      viewItem.icon <- actionBarType.getIcon(item, killStreakUnitTag)
      viewItem.name <- actionBarType.getTitle(item, killStreakTag)
      viewItem.tooltipText <- actionBarType.getTooltipText(item)
    }

    return viewItem
  }

  function getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime, isReverse = false) {
    let res = { degree = 360, incFactor = 0 }
    let cooldownDuration = cooldownEndTime - get_mission_time()
    if (cooldownDuration <= 0)
      return res

    let degree = clamp((1 - cooldownDuration / max(cooldownTime, 1)) * 360, 0, 360).tointeger()
    return {
      degree = isReverse ? 360 - degree : degree
      incFactor = degree == 360 ? 0
        : (360 - degree) / cooldownDuration * (isReverse ? -1 : 1)
    }
  }

  function replaceItem(item, nestIndex) {
    let partails = {
      textShortcut    = this.canControl ? loadTemplateText("%gui/hud/actionBarItemTextShortcut.tpl")    : ""
      gamepadShortcut = this.canControl ? loadTemplateText("%gui/hud/actionBarItemGamepadShortcut.tpl") : ""
    }

    let action_bar_items_nest = this.scene.findObject("action_bar")
    let itemView = this.buildItemView(item, nestIndex, true)
    itemView["noNeedNest"] <- true
    let itemBlk = handyman.renderCached("%gui/hud/actionBarItem.tpl", itemView, partails)
    this.guiScene.replaceContentFromText(action_bar_items_nest.findObject( $"{nestIndex}_nest"), itemBlk, itemBlk.len(), this)
  }

  function updateWaitGaugeDegree(obj, waitGaugeDegreeParams) {
    let { degree, incFactor } = waitGaugeDegreeParams
    let incFactorStr = format("%.1f", incFactor)
    if (degree == (obj.getFinalProp(sectorAngle1PID) ?? -1).tointeger()
        && incFactorStr == obj?["inc-factor"])
      return
    obj["inc-factor"] = incFactorStr
    obj.set_prop_latent(sectorAngle1PID, degree)
    obj.updateRendElem()
  }

  function onUpdate(_obj = null, _dt = 0.0) {
    updateActionBar()
  }

  function updateActionBarItems(items) {
    let prevActionItems = this.actionItems
    this.actionItems = items
    this.updateKillStreakWheel()

    if ((prevActionItems?.len() ?? 0) != this.actionItems.len() || this.actionItems.len() == 0) {
      this.openSecondActionsMenu(null)
      this.fill()
      return
    }

    let hudUnitType = getHudUnitType()
    let unit = this.getActionBarUnit()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX

    local newActionWithMenu = this.currentActionWithMenu

    foreach (id, item in this.actionItems) {
      let prevItem = prevActionItems[id]
      if (item == prevItem)
        continue

      if (newActionWithMenu == prevItem)
        newActionWithMenu = item?.isWaitSelectSecondAction ? item : null
      else if (item?.isWaitSelectSecondAction)
        newActionWithMenu = item

      if (needFullUpdate(item, prevItem, hudUnitType)) {
        this.replaceItem(item, id)
        continue
      }

      if (this.cooldownTimers?[id])
        clearTimer(this.cooldownTimers[id])

      let itemObjId = getActionBarObjId(item.id)
      let itemObj = this.scene.findObject(itemObjId)

      if (!(itemObj?.isValid() ?? false))
        continue

      itemObj.findObject("amount_text").setValue(getActionItemAmountText(item))
      itemObj.findObject("automatic_text")?.show(ship && item?.automatic)

      let actionType = item.type
      let { isReady } = getActionItemStatus(item)

      if (item?.importantFire != null)
        this.blinkImportantFire(itemObj, item.importantFire && isReady)

      if (actionType != EII_BULLET && !itemObj.isEnabled() && isReady && item?.importantFire != true)
        this.blink(itemObj)

      let actionBarType = g_hud_action_bar_type.getByActionItem(item)
      if (actionBarType.needAnimOnIncrementCount)
        this.handleIncrementCount(item, prevActionItems[id], itemObj)

      itemObj.selected = item.selected ? "yes" : "no"
      itemObj.active = item.active ? "yes" : "no"
      itemObj.enable(isReady)
      if (item?.isWaitSelectSecondAction != prevItem?.isWaitSelectSecondAction ) {
        let collapseBtn = itemObj.findObject("actionCollapseBtn")
        if (collapseBtn != null)
          collapseBtn["rotation"] = item?.isWaitSelectSecondAction ? "180" : "0"
      }

      let mainActionButtonObj = itemObj.findObject("mainActionButton")
      let activatedActionButtonObj = itemObj.findObject("activatedActionButton")
      let cancelButtonObj = itemObj.findObject("cancelButton")
      if ((mainActionButtonObj?.isValid() ?? false)
        && (activatedActionButtonObj?.isValid() ?? false)
        && (cancelButtonObj?.isValid() ?? false)) {
          mainActionButtonObj.show(!item.active)
          activatedActionButtonObj.show(item.active)
          cancelButtonObj.show(item.active)
      }

      let backgroundImage = actionBarType.getIcon(item, null, unit, hudUnitType)
      let iconObj = itemObj.findObject("action_icon")
      if ((iconObj?.isValid() ?? false) && backgroundImage.len() > 0)
        iconObj["background-image"] = backgroundImage
      if (actionType == EII_EXTINGUISHER && (mainActionButtonObj?.isValid() ?? false))
        mainActionButtonObj.show(isReady)
      if (actionType == EII_ARTILLERY_TARGET && item.active != this.artillery_target_mode) {
        this.artillery_target_mode = item.active
        broadcastEvent("ArtilleryTarget", { active = this.artillery_target_mode })
      }

      if (actionType != prevActionItems[id].type || actionType == EII_GUIDANCE_MODE)
        this.scene.findObject($"tooltip_{itemObjId}").tooltip = actionBarType.getTooltipText(item)

      let { cooldownEndTime = 0, cooldownTime = 1, inProgressTime = 1, inProgressEndTime = 0,
        blockedCooldownEndTime = 0, blockedCooldownTime = 1, active = true, available = true } = item
      let cooldownParams = available ? this.getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime)
        : notAvailableColdownParams

      let cooldownTimeout = cooldownEndTime - get_mission_time()
      if (cooldownTimeout > 0)
        this.enableBarItemAfterCooldown(id, cooldownTimeout)

      this.updateWaitGaugeDegree(itemObj.findObject("cooldown"), cooldownParams)
      this.updateWaitGaugeDegree(itemObj.findObject("blockedCooldown"),
        this.getWaitGaugeDegreeParams(blockedCooldownEndTime, blockedCooldownTime))
      this.updateWaitGaugeDegree(itemObj.findObject("progressCooldown"),
        this.getWaitGaugeDegreeParams(inProgressEndTime, inProgressTime, !active))
    }

    this.openSecondActionsMenu(newActionWithMenu)
  }

  function enableBarItemAfterCooldown(itemIdx, timeout) {
    
    
    timeout += 0.5

    let cb = Callback(function() {
      let item = this.actionItems?[itemIdx]
      if (!item || !this.scene?.isValid())
        return
      let itemObjId = getActionBarObjId(item.id)
      let itemObj = this.scene.findObject(itemObjId)
      if (!itemObj?.isValid() || !getActionItemStatus(item).isReady)
        return
      itemObj.enable(true)
    }, this)

    let timer = setTimeout(timeout, @() cb())

    if (this.cooldownTimers.len() <= itemIdx)
      this.cooldownTimers.resize(itemIdx + 1)
    this.cooldownTimers[itemIdx] = timer
  }

  function flushCooldownTimers() {
    while (this.cooldownTimers.len() > 0)
      clearTimer(this.cooldownTimers.pop())
  }

  



  function handleIncrementCount(currentItem, prewItem, itemObj) {
    if ((prewItem.countEx == currentItem.countEx && prewItem.count < currentItem.count)
      || (prewItem.countEx < currentItem.countEx)
      || (prewItem.ammoLost < currentItem.ammoLost)) {
      let delta = currentItem.countEx - prewItem.countEx || currentItem.count - prewItem.count
      if (prewItem.ammoLost < currentItem.ammoLost)
        g_hud_event_manager.onHudEvent("hint:ammoDestroyed:show")
      let blk = handyman.renderCached("%gui/hud/actionBarIncrement.tpl", { is_increment = delta > 0, delta_amount = delta })
      this.guiScene.appendWithBlk(itemObj, blk, this)
    }
  }

  function blink(obj) {
    let blinkObj = obj.findObject("availability")
    if (checkObj(blinkObj))
      blinkObj["_blink"] = "yes"
  }

  function blinkImportantFire(obj, enabled) {
    let blinkObj = obj.findObject("importantFire")
    if (checkObj(blinkObj))
      blinkObj["_blink"] = enabled ? "loop" : "no"
  }

  function updateVisibility() {
    if (!this.isValid())
      return

    let showActionBarOption = get_gui_option_in_mode(USEROPT_SHOW_ACTION_BAR, OPTIONS_MODE_GAMEPLAY, true)
    this.isVisible = showActionBarOption && !g_hud_live_stats.isVisible() && !isVisualHudAirWeaponSelectorOpened()
    this.scene.show(this.isVisible)
    eventbus_send("setIsActionBarVisible", this.isVisible)
  }

  function activateAction(obj) {
    let action = this.getActionByObj(obj)
    if (action == null)
      return
    if (this.currentActionWithMenu && this.currentActionWithMenu.isWaitSelectSecondAction) {
      foreach (idx, secondAction in this.currentActionWithMenu.additionalBulletInfo) {
        if (secondAction.selected) {
          emulateShortcut(g_hud_action_bar_type.BULLET.getShortcut({shortcutIdx = idx}))
          if (this.currentActionWithMenu == action) {
            updateActionBar()
            return
          }
          break
        }
      }
    }

    let shortcut = g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
    if (shortcut)
      toggleShortcut(shortcut)

    if (action?.additionalBulletInfo)
      updateActionBar()
  }

  function openSecondActionsMenu(action) {
    if (action == this.currentActionWithMenu)
      return

    if (action == null) {
      this.closeSecondActionsMenu()
      return
    }
    this.currentActionWithMenu = action
    if (action?.additionalBulletInfo) {
      let actionObjId = getActionBarObjId(action.id)
      let actionObj = this.scene.findObject(actionObjId)
      this.showSecondActions(actionObj, action)
    }
  }

  function closeSecondActionsMenu() {
    if (!this.currentActionWithMenu)
      return

    this.hideSecondActions()
    this.currentActionWithMenu = null
    clearTimer(this.closeSecondActionsTimer)
  }

  function emulateCloseSecondActions() {
    if (!this.currentActionWithMenu?.isWaitSelectSecondAction)
      return
    foreach (idx, secondAction in this.currentActionWithMenu.additionalBulletInfo)
      if (secondAction.selected) {
        emulateShortcut(g_hud_action_bar_type.BULLET.getShortcut({shortcutIdx = idx}))
        break
      }
  }

  function onSecondActionClick(obj) {
    let itemId = obj.id.slice(-(obj.id.len() - SECOND_ACTION_ID_PREFIX.len())).tointeger()
    emulateShortcut(g_hud_action_bar_type.BULLET.getShortcut({shortcutIdx = itemId}))
    updateActionBar()
  }

  function showSecondActions(obj, action = null) {
    action = action ?? this.getActionByObj(obj)

    if ((action?.additionalBulletInfo.len() ?? 0) == 0)
      return

    let secondItemsParams = this.generateSecondActions(action.additionalBulletInfo, action.triggerGroupNo)
    secondItemsParams.posx <- obj.getPos()[0]
    secondItemsParams.posy <- this.hasXInputSh ? this.getXInputShHeight() : this.getTextShHeight()

    let blk = handyman.renderCached(("%gui/hud/actionBarSecondItems.tpl"), secondItemsParams)
    this.guiScene.replaceContentFromText(this.scene.findObject("secondActions"), blk, blk.len(), this)

    clearTimer(this.closeSecondActionsTimer)
    let handler = this
    this.closeSecondActionsTimer = setTimeout(SECOND_ACTIONS_MENU_LIFETIME, @() handler.isValid() ? handler.emulateCloseSecondActions() : null)
  }

  function hideSecondActions() {
    this.guiScene.replaceContentFromText(this.scene.findObject("secondActions"), "", 0, this)
  }

  function generateSecondActions(secondActions, triggerGroupNo = 0) {
    local header = null
    if (triggerGroupNo == 0)
      header = loc("controls/help/ship/manual-targeting-primary")
    else if (triggerGroupNo == 1)
      header = loc("controls/help/ship/manual-targeting-secondary")
    else
      header = loc("HUD/ALL_ADDITIONAL_GUNS")

    let shortcuts = []
    let items = []
    let actionShortNames = []
    let unit = this.getActionBarUnit()

    foreach (index, action in secondActions) {
      let item = this.buildSecondItemView(action, index)
      local code = $"ID_SHIP_ACTION_BAR_ITEM_{index+1}"

      let shType = g_shortcut_type.getShortcutTypeByShortcutId(code)
      let scInput = shType.getFirstInput(code)
      let shortcutText = scInput.getTextShort()
      let isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
      shortcuts.append({shortcut = shortcutText, isXinput, mainShortcutId = code})

      items.append(item)
      local shortName = "--"
      if (action.modificationName) {
        let bullets = getBulletsSetData(unit, action.modificationName)
        shortName = loc($"{bullets.bullets[0]}/name/short")
      }
      actionShortNames.append({shortName})
    }

    return {
      itemsCount = items.len()
      shortcuts
      items
      header
      actionShortNames
    }
  }

  
  function activateStreak(streakId) {
    let action = this.killStreaksActionsOrdered?[streakId]
    if (action)
      return activateShortcutActionBarAction(action)

    if (streakId >= 0) { 
      debugTableData(this.killStreaksActionsOrdered)
      debug_dump_stack()
      assert(false, "Error: killStreak id out of range.")
    }
  }

  function activateWeapon(streakId) {
    let action = getTblValue(streakId, this.weaponActions)
    if (action) {
      let shortcut = g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
      toggleShortcut(shortcut)
    }
  }


  function getActionByObj(obj) {
    let actionItemNum = obj.id.slice(-(obj.id.len() - ACTION_ID_PREFIX.len())).tointeger()
    foreach (item in this.actionItems)
      if (item.id == actionItemNum)
        return item
    return null
  }

  function toggleKillStreakWheel(open) {
    if (!checkObj(this.scene))
      return

    if (!open) {
      closeCurWheelmenu()
      return
    }

    if (!this.useWheelmenu)
      return

    this.updateKillStreaksActions()
    if (this.killStreaksActions.len() == 0)
      return

    if (this.killStreaksActions.len() == 1) {
      this.guiScene.performDelayed(this, function() {
        activateShortcutActionBarAction(this.killStreaksActions[0])
        closeCurWheelmenu()
      })
      return
    }

    closeCurVoicemenu()
    this.fillKillStreakWheel()
  }

  function fillKillStreakWheel(isUpdate = false) {
    this.killStreaksActionsOrdered = arrangeStreakWheelActions(getActionBarUnitName(),
      getHudUnitType(), this.killStreaksActions)

    let menu = []
    foreach (action in this.killStreaksActionsOrdered)
      menu.append(action != null ? this.buildItemView(action) : null)

    let params = {
      menu            = menu
      callbackFunc    = this.activateStreak
      contentTemplate = "%gui/hud/actionBarItemStreakWheel.tpl"
      owner           = this
    }

    guiStartWheelmenu(params, isUpdate)
  }

  function updateKillStreaksActions() {
    this.killStreaksActions = []
    foreach (item in this.actionItems)
      if (g_hud_action_bar_type.getByActionItem(item).isForWheelMenu())
        this.killStreaksActions.append(item)
  }

  function updateKillStreakWheel() {
    if (!this.useWheelmenu)
      return

    let handler = handlersManager.findHandlerClassInScene(gui_handlers.wheelMenuHandler)
    if (!(handler?.isActive ?? false))
      return

    let prevActions = this.killStreaksActions
    this.updateKillStreaksActions()

    local update = false
    if (this.killStreaksActions.len() != prevActions.len())
      update = true
    else {
      for (local i = this.killStreaksActions.len() - 1; i >= 0; i--)
        if (this.killStreaksActions[i].active != prevActions[i].active
          || getActionItemStatus(this.killStreaksActions[i]).isReady != getActionItemStatus(prevActions[i]).isReady
          || this.killStreaksActions[i].count != prevActions[i].count
          || this.killStreaksActions[i].countEx != prevActions[i].countEx) {
          update = true
          break
        }
    }

    if (update)
      this.fillKillStreakWheel(true)
  }

  function updateWeaponActions() {
    this.weaponActions = []
    if (getHudUnitType() == "")
      return
    let rawWheelItem = getWheelBarItems()
    foreach (item in rawWheelItem)
      if (g_hud_action_bar_type.getByActionItem(item).isForSelectWeaponMenu())
        this.weaponActions.append(item)
  }

  function toggleSelectWeaponWheel(open) {
    if (!checkObj(this.scene))
      return

    if (open)
      this.fillSelectWaponWheel()
    else
      closeCurWheelmenu()
  }

  function fillSelectWaponWheel() {
    this.updateWeaponActions()
    let menu = []
    foreach (action in this.weaponActions)
      menu.append(this.buildItemView(action))
    let params = {
      menu            = menu
      callbackFunc    = this.activateWeapon
      contentTemplate = "%gui/hud/actionBarItemStreakWheel.tpl"
      owner           = this
    }
    guiStartWheelmenu(params)
  }

  function onTooltipObjClose(obj) {
    closeGenericTooltip(obj, this)
  }

  function onGenericTooltipOpen(obj) {
    openGenericTooltip(obj, this)
  }

  function onVisualSelectorClick(_obj) {
    openHudAirWeaponSelector()
  }

}

eventbus_subscribe("ActionBarCollapseBtnHidden", function(isHidden) {
  isCollapseBtnHidden = isHidden
  let path = getVisibilityStateProfilePath()
  if (path == null)
    return
  saveLocalByAccount(path, isHidden ? ActionBarVsisbility.HIDDEN : ActionBarVsisbility.EXPANDED)
})


return {
  ActionBar
  getActionBarObjId
}