from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import fakeBullets_prefix
import "%sqstd/ecs.nut" as ecs

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { g_hud_live_stats } = require("%scripts/hud/hudLiveStats.nut")
let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent, add_event_listener, subscribe_handler
} = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { hasXInputDevice, emulateShortcut } = require("controls")
let { format } = require("string")
let { debug_dump_stack } = require("dagor.debug")
let { isFakeBullet, getBulletsSetData } = require("%scripts/weaponry/bulletsInfo.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { shouldActionBarFontBeTiny , getActionItemAmountText, getActionItemModificationName,
  getActionItemStatus, curHeroTemplates } = require("%scripts/hud/hudActionBarInfo.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getWheelBarItems, activateActionBarAction, getActionBarUnitName } = require("hudActionBar")
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_EXTINGUISHER, EII_ROCKET, EII_FORCED_GUN, EII_SLAVE_UNIT_STATUS,
  EII_SELECT_SPECIAL_WEAPON, EII_GRENADE } = require("hudActionBarConst")
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
let { isVisualHudAirWeaponSelectorOpened, setWeaponSelectorAttachedToActionBar,
 isWeaponSelectorSavedPinnedState } = require("%scripts/hud/hudAirWeaponSelector.nut")
let { getExtraActionItemsView, WEAPON_SELECTOR_SHORTCUT_ID
} = require("%scripts/hud/hudActionBarExtraActions.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { isPlayerDedicatedSpectator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { bhvHintForceUpdateValuePID } = require("%scripts/viewUtils/bhvHint.nut")
let forceRealTimeRenderIcon = require("%globalScripts/iconRender/forceRealTimeRenderIcon.nut")

ecs.register_es("current_weapons_templates_init_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    curHeroTemplates.set(comp["human_weap__weapTemplates"]?.getAll())
  },
  [["onDestroy"]] = function(_, _) {
    curHeroTemplates.set({})
  }
},
{
  comps_track=[["human_weap__weapTemplates", ecs.TYPE_OBJECT, {}]],
  comps_rq=["controlledHero"]
})

curHeroTemplates.subscribe(@(_) broadcastEvent("ChangedCurHeroTemplates"))
forceRealTimeRenderIcon.subscribe(@(_v) broadcastEvent("UpdateForceRender3dIcon"))

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

const AUTO_COLLAPSE_DELAY_SEC = 20
let unitTypesWithDelayedCollapse = ["aircraft", "helicopter"]

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

function getVisibilityStateProfilePath() {
  let hudType = hudTypeByHudUnitType?[getHudUnitType()]
  if (hudType == null)
    return null
  return $"actionBar/isCollapsed/{hudType}"
}

let class ActionBar {
  actionItems             = null
  rawActionItems          = null
  guiScene                = null
  scene                   = null

  canControl              = true
  useWheelmenu            = false
  killStreaksActions      = null
  killStreaksActionsOrdered = null
  weaponActions           = null

  actionBarSecondItemsTpl = null
  actionBarItemBlk = null
  actionBarItemDivName = null

  artillery_target_mode = false

  curActionBarUnitName = null

  isFootballMission = false

  cooldownTimers = null

  isCollapsed = false
  isVisible = false
  hasSavedVisibilityState = false
  autoCollapseTimer = null
  hasXInputSh = false
  closeSecondActionsTimer = null

  currentActionWithMenu = null
  extraActionsCount = 0
  extraActions = null
  isWeaponSelectorMode = false

  shouldForceUpdateItems = false

  getActionBarVisibility = @() isCollapseBtnHidden ? ActionBarVsisbility.HIDDEN
    : this.isCollapsed ? ActionBarVsisbility.COLLAPSED
    : ActionBarVsisbility.EXPANDED

  notifyActionBarStateChanged = @() get_cur_gui_scene()
    .performDelayed(this, @() eventbus_send("setActionBarState", this.getState()))

  constructor(nestObj, itemBlk = null, itemDivName = null, secondItemsTpl = null) {
    if (!checkObj(nestObj))
      return
    this.scene     = nestObj
    this.guiScene  = nestObj.getScene()
    this.actionBarSecondItemsTpl = secondItemsTpl ?? "%gui/hud/actionBarSecondItems.tpl"
    this.actionBarItemBlk = itemBlk ?? "%gui/hud/actionBarItem.blk"
    this.actionBarItemDivName = itemDivName ?? "actionBarItemDiv"
    this.guiScene.replaceContent(this.scene.findObject("actions_nest"), "%gui/hud/actionBar.blk", this)
    this.scene.findObject("action_bar").setUserData(this)
    this.actionItems = []
    this.rawActionItems = []
    this.killStreaksActions = []
    this.weaponActions = []
    this.cooldownTimers = []

    this.canControl = !isPlayerDedicatedSpectator() && !is_replay_playing()

    this.isFootballMission = (get_game_type() & GT_FOOTBALL) != 0

    let savedVisibilityPath = getVisibilityStateProfilePath()
    if (isProfileReceived.get() && savedVisibilityPath != null) {
      let savedVisibility = loadLocalByAccount(savedVisibilityPath)
      let visibilityState = savedVisibility ?? ActionBarVsisbility.EXPANDED
      this.isCollapsed = visibilityState != ActionBarVsisbility.EXPANDED
      this.hasSavedVisibilityState = savedVisibility != null
      updateExtWatched({ isActionBarCollapseBtnHidden = visibilityState == ActionBarVsisbility.HIDDEN })
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
      this.scheduleAutoCollapseIfNeeded()
    }, this)
    add_event_listener("ChangedShowActionBar", function (_eventData) {
      this.updateVisibility()
      if (this.isWeaponSelectorMode)
        this.notifyActionBarStateChanged()
    }, this)
    add_event_listener("ControlsChangedShortcuts", function (_eventData) {
      this.shouldForceUpdateItems = true
    }, this)
    add_event_listener("ControlsPresetChanged", function (_eventData) {
      this.shouldForceUpdateItems = true
    }, this)
    add_event_listener("ChangedCurHeroTemplates", function (_eventData) {
      this.shouldForceUpdateItems = true
      this.reinit()
    }, this)
    add_event_listener("UpdateForceRender3dIcon", function (_eventData) {
      this.shouldForceUpdateItems = true
      this.reinit()
    }, this)

    subscribe_handler(this)

    this.updateParams()
    updateActionBar()
    this.updateExtraActionsAndMode()
    this.scheduleAutoCollapseIfNeeded()
    this.scene.setValue(stashBhvValueConfig([{
      watch = actionBarItems
      updateFunc = Callback(@(_obj, actionItems) this.updateActionBarItems(actionItems), this) 
    }]))
  }

  isCollapsable = @() this.canControl && ((this.actionItems.len() + this.extraActionsCount) > 0)

  function collapse() {
    if (this.isWeaponSelectorMode && this.isCollapsed && isVisualHudAirWeaponSelectorOpened())
      return
    this.setCollapsedState(!this.isCollapsed)
    this.clearAutoCollapseTimer()
  }

  function setCollapsedState(needCollapse, needSave = true) {
    if (!this.isValid())
      return
    if (!this.isCollapsable())
      return
    if (this.isCollapsed == needCollapse)
      return

    this.isCollapsed = needCollapse
    if (!this.isCollapsed)
      isCollapseBtnHidden = false

    if (needSave && isProfileReceived.get()) {
      let visibilityPath = getVisibilityStateProfilePath()
      if (visibilityPath != null) {
        saveLocalByAccount(visibilityPath, this.getActionBarVisibility())
        this.hasSavedVisibilityState = true
      }
    }

    if (!this.isCollapsed)
      updateActionBar()

    this.scene.findObject("actions_nest").anim = this.isCollapsed ? "hide" : "show"
    eventbus_send("setIsActionBarCollapsed", this.isCollapsed)
    this.syncWithWeaponSelector()
  }

  function scheduleAutoCollapseIfNeeded() {
    if (this.hasSavedVisibilityState)
      return
    if (!this.isCollapsable())
      return
    let unitType = getHudUnitType()
    if (!unitTypesWithDelayedCollapse.contains(unitType))
      return
    let hasToggleCollapseSh = getCollapseShText().getText() != ""
    if (!hasToggleCollapseSh)
      return

    this.setCollapsedState(false, false)
    this.clearAutoCollapseTimer()
    if (this.isWeaponSelectorMode && isWeaponSelectorSavedPinnedState())
      return

    let cb = Callback(function autoCollapse() {
      if (!this?.isValid())
        return

      this.autoCollapseTimer = null

      if (this.isCollapsed)
        return

      this.setCollapsedState(true, false)
      eventbus_send("actionBarAutoCollapse")
    }, this)
    this.autoCollapseTimer = setTimeout(AUTO_COLLAPSE_DELAY_SEC, @() cb())
  }

  function clearAutoCollapseTimer() {
    if (this.autoCollapseTimer == null)
      return
    clearTimer(this.autoCollapseTimer)
    this.autoCollapseTimer = null
  }

  getTextShHeight = @() to_pixels("@hudActionBarTextShHight")
  getXInputShHeight = @() to_pixels("0.036@shHud")

  function getActionBarAABB() {
    if (!this.isValid())
      return null

    let obj = this.isWeaponSelectorMode
      ? this.scene.getParent().findObject("air_weapon_selector")
      : this.scene.findObject("action_bar")
    if (!obj?.isValid())
      return null
    let size = obj.getSize()
    if (size[0] < 0)
      return null 

    let extraHeight = this.isWeaponSelectorMode ? 0
      : this.hasXInputSh ? this.getXInputShHeight()
      : this.getTextShHeight()
    let pos = (this.isWeaponSelectorMode ? obj : this.scene).getPosRC()
    pos[1] -= extraHeight
    size[1] += extraHeight
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
      actionsCount = this.actionItems.len()
    }
  }

  function syncWithWeaponSelector() {
    if (!this.isValid())
      return
    let shouldAttach = this.isWeaponSelectorMode && this.canControl
      && !this.isCollapsed && this.isVisible

    this.scene.findObject("actions_nest")?.show(!this.isWeaponSelectorMode)
    setWeaponSelectorAttachedToActionBar(shouldAttach)
  }

  function reinit() {
    this.updateParams()
    updateActionBar()
    this.updateActionBarItems(actionBarItems.get())
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

  function fillActionBarItem(itemObj, itemView) {
    let { id, selected, active, activeBool, actionId, enableBool, visualEnable, layeredIcon = null,
      cooldownParams, blockedCooldownParams progressCooldownParams, amount, automatic, onClick = null
      showShortcut, isXinput, mainShortcutId, activatedShortcutId = "", actionType = null
      hasSecondActionsBtn, isCloseSecondActionsBtn, shortcutText, useShortcutTinyFont,
      tooltipId = null, tooltipText = "", tooltipDelayed = false, unitIndex = "", isLocked = false,
      icon = "", cooldownIcon = ""
    } = itemView
    itemObj.id = id
    let contentObj = itemObj.findObject("itemContent")
    contentObj.selected = selected
    contentObj.active = active
    contentObj.actionId = actionId
    contentObj.shortcutId = mainShortcutId
    contentObj.overrideClick = onClick != null ? onClick : ""
    contentObj.visualEnable = visualEnable

    let isShowBulletsIcon = layeredIcon != null
    let bulletsSetIconObj = showObjById("bulletsSetIcon", isShowBulletsIcon, contentObj)
    if (isShowBulletsIcon && bulletsSetIconObj != null)
      this.guiScene.replaceContentFromText(bulletsSetIconObj, layeredIcon, layeredIcon.len(), this)

    let isShowIcon = icon != ""
    let actionIconObj = showObjById("action_icon", isShowIcon, contentObj)
    if (isShowIcon)
      actionIconObj["background-image"] = icon

    let cooldownObj = itemObj.findObject("cooldown")
    if (cooldownObj && cooldownIcon != "")
      cooldownObj["background-image"] = cooldownIcon
    this.updateWaitGaugeDegree(cooldownObj, cooldownParams)

    let blockedCooldownObj = itemObj.findObject("blockedCooldown")
    if (blockedCooldownObj && cooldownIcon != "")
      blockedCooldownObj["background-image"] = cooldownIcon
    this.updateWaitGaugeDegree(blockedCooldownObj, blockedCooldownParams)

    let progressCooldownObj = itemObj.findObject("progressCooldown")
    if (progressCooldownObj && cooldownIcon != "")
      progressCooldownObj["background-image"] = cooldownIcon
    this.updateWaitGaugeDegree(progressCooldownObj, progressCooldownParams)

    this.setItemAmountText(itemObj, amount)
    contentObj.findObject("automatic_text").show(automatic)

    let isShowGamepadShortcut = showShortcut && isXinput
    let hasMainAction = isShowGamepadShortcut && mainShortcutId != ""
    let hasActivateAction = isShowGamepadShortcut && activatedShortcutId != ""
    let isShowMainAction = hasMainAction && (actionType != EII_EXTINGUISHER || enableBool)
    let mainActionButtonObj = showObjById("mainActionButton", isShowMainAction, contentObj)
    if (hasMainAction) {
      if (this.shouldForceUpdateItems)
        mainActionButtonObj.setIntProp(bhvHintForceUpdateValuePID, 1)
      mainActionButtonObj.setValue("".concat("{{", mainShortcutId, "}}"))
      mainActionButtonObj.top = hasActivateAction && activeBool ? "h + 0.005@shHud"
        : "- h - 0.005@shHud"
    }

    let activatedActionButtonObj = showObjById("activatedActionButton", activeBool && hasActivateAction, contentObj)
    activatedActionButtonObj.hasShortcut = hasActivateAction ? "yes" : "no"
    if (hasActivateAction) {
      if (this.shouldForceUpdateItems)
        activatedActionButtonObj.setIntProp(bhvHintForceUpdateValuePID, 1)
      activatedActionButtonObj.setValue("".concat("{{", activatedShortcutId, "}}"))
    }

    let isShowTextShortcut = showShortcut && !isXinput
    let shortcutTextNestObj = showObjById("shortcutTextNest", isShowTextShortcut, contentObj)
    if (isShowTextShortcut) {
      let shortcutTextObj = shortcutTextNestObj.findObject("shortcutText")
      shortcutTextObj.hudFont = useShortcutTinyFont  ? "tiny" : "small"
      shortcutTextObj.setValue(shortcutText)
      let actionCollapseBtnObj = showObjById("actionCollapseBtn", hasSecondActionsBtn, shortcutTextNestObj)
      if (actionCollapseBtnObj)
        actionCollapseBtnObj.rotation = isCloseSecondActionsBtn ? "180" : "0"
    }

    let tooltipLayerObj = itemObj.findObject("tooltipLayer")
    if (tooltipId != null) {
      tooltipLayerObj["tooltip-timeout"] = tooltipDelayed ? "1000" : ""
      tooltipLayerObj.tooltip = "$tooltipObj"
      let tooltipObj = tooltipLayerObj.findObject("tooltipObj")
      tooltipObj.tooltipId = tooltipId
    } else {
      tooltipLayerObj["tooltip-timeout"] = ""
      tooltipLayerObj.tooltip = tooltipText
    }

    itemObj.findObject("unitIndex").setValue(unitIndex)
    itemObj.findObject("lockedIcon").show(isLocked)
  }

  function fill(prevActionItems) {
    this.extraActionsCount = 0
    this.extraActions?.clear()
    this.flushCooldownTimers()
    if (!checkObj(this.scene))
      return

    this.curActionBarUnitName = getActionBarUnitName()
    this.updateExtraActionsAndMode()
    let fullItemsList = this.actionItems
      .map((@(a, idx) this.buildItemView(a, idx, true)).bindenv(this))
      .extend(this.extraActions)

    local newActionWithMenu = null
    foreach (idx, item in this.actionItems) {
      if (item?.isWaitSelectSecondAction)
        newActionWithMenu = item
      let cooldownTimeout = (item?.cooldownEndTime ?? 0) - get_mission_time()
      if (cooldownTimeout > 0)
        this.enableBarItemAfterCooldown(idx, cooldownTimeout)
    }

    this.guiScene.setUpdatesEnabled(false, false)
    let actionBarObj = this.scene.findObject("action_bar")
    let listItemsCount = actionBarObj.childrenCount()
    let needListItemsCount = fullItemsList.len()
    if (needListItemsCount > listItemsCount)
      this.guiScene.createMultiElementsByObject(actionBarObj, this.actionBarItemBlk,
        this.actionBarItemDivName, needListItemsCount - listItemsCount, this)

    for (local i = 0; i < actionBarObj.childrenCount(); i++) {
      let itemObj = actionBarObj.getChild(i)
      if (i >= needListItemsCount) {
        itemObj.show(false)
        continue
      }

      let curActionItem = this.actionItems?[i]
      if (!this.shouldForceUpdateItems && curActionItem != null && curActionItem == prevActionItems?[i])
        continue

      itemObj.show(true)
      this.fillActionBarItem(itemObj, fullItemsList[i])
    }
    this.guiScene.setUpdatesEnabled(true, true)

    broadcastEvent("HudActionbarInited", { actionBarItemsAmount = this.actionItems.len() + this.extraActionsCount })

    this.hasXInputSh = fullItemsList.findindex(@(item) item.showShortcut && item.isXinput) != null
    let shHeight = this.hasXInputSh ? this.getXInputShHeight() : this.getTextShHeight()
    let animObj = this.scene.findObject("actions_nest")
    animObj["top-end"] = to_pixels("@hudActionBarItemSize") + shHeight
    let isShow = !this.isCollapsable() || !this.isCollapsed
    animObj.anim = isShow ? "show" : "hide"
    animObj["_transp-timer"] = isShow ? "1" : "0"
    animObj["_pos-timer"] = isShow ? "0" : "1"

    this.updateVisibility()
    this.syncWithWeaponSelector()
    this.openSecondActionsMenu(newActionWithMenu)
    this.notifyActionBarStateChanged()
  }

  
  function buildItemView(item, itemIdx, needShortcuts = false) {
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
      let scInputText = scInput.getTextShort()
      shortcutText = (scInput?.elements.len() ?? 0) > 1 ? scInputText.replace(" ", "") : scInputText
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
      id                  = getActionBarObjId(itemIdx)
      actionId            = item.id
      actionType          = item.type
      selected            = item.selected ? "yes" : "no"
      active              = active ? "yes" : "no"
      activeBool          = active
      visualEnable        = isReady ? "yes" : "no"
      enableBool          = isReady
      wheelmenuEnabled    = true
      shortcutText        = shortcutText
      useShortcutTinyFont = shouldActionBarFontBeTiny(shortcutText)
      mainShortcutId      = shortcutId
      isXinput            = showShortcut && isXinput
      showShortcut        = showShortcut
      amount              = getActionItemAmountText(item)
      cooldown                  = cooldownParams.degree
      cooldownIncFactor         = cooldownParams.incFactor
      cooldownParams
      blockedCooldownParams
      progressCooldownParams
      automatic                 = ship && (item?.automatic ?? false)
      hasSecondActionsBtn = item?.additionalBulletInfo != null
      isCloseSecondActionsBtn = item?.isWaitSelectSecondAction ?? false
    }

    if (item.type == EII_SLAVE_UNIT_STATUS) {
      viewItem.unitIndex <- $"{item.innerIdx + 1}"
      viewItem.isLocked <- item.available && !item.active
    }

    let unit = this.getActionBarUnit()
    let modifName = getActionItemModificationName(item, unit)
    if (modifName) {
      
      if (isFakeBullet(modifName) && !(modifName in unit.bulletsSets))
        getBulletsSetData(unit, fakeBullets_prefix, {})
      let data = getBulletsSetData(unit, modifName)
      viewItem.layeredIcon <- handyman.renderCached("%gui/weaponry/bullets.tpl", getBulletsIconView(data))
      viewItem.tooltipId <- MODIFICATION.getTooltipId(unit.name, modifName, { isInHudActionBar = true })
      viewItem.tooltipDelayed <- !this.canControl
    }
    else if (item.type == EII_ARTILLERY_TARGET) {
      viewItem.activatedShortcutId <- "ID_SHOOT_ARTILLERY"
    }

    if (!modifName && item.type != EII_BULLET && item.type != EII_FORCED_GUN) {
      let killStreakTag = getTblValue("killStreakTag", item)
      let killStreakUnitTag = getTblValue("killStreakUnitTag", item)
      if ("getLayeredIcon" in actionBarType)
        viewItem.layeredIcon <- actionBarType.getLayeredIcon(null, null, unit)
      else {
        viewItem.icon <- actionBarType.getIcon(item, killStreakUnitTag)
        viewItem.cooldownIcon <- actionBarType.getCooldownIcon(item, killStreakUnitTag)
      }
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
      actionId = itemId
      selected = item.selected ? "yes" : "no"
      active = item.selected ? "yes" : "no"
      available = available
      visualEnable = item.count > 0 ? "yes" : "no"
      enableBool = item.count > 0
      amount = item.count
      cooldown = cooldownParams.degree
      cooldownIncFactor = cooldownParams.incFactor
      blockedCooldown           = blockedCooldownParams.degree
      blockedCooldownIncFactor  = blockedCooldownParams.incFactor
      progressCooldown          = progressCooldownParams.degree
      progressCooldownIncFactor = progressCooldownParams.incFactor
      inProgressTime = 0.0
      nopadding = true
      countEx = -1
      onClick = "onSecondActionClick"
      broken = false
    }

    let unit = this.getActionBarUnit()
    if (item?.type == EII_BULLET) {
      let data = getBulletsSetData(unit, item.modificationName)
      viewItem.layeredIcon <- handyman.renderCached("%gui/weaponry/bullets.tpl", getBulletsIconView(data))
      viewItem.tooltipId <- MODIFICATION.getTooltipId(unit.name, item.modificationName, { isInHudActionBar = true })
    } else if (item?.type != null && item.type != EII_BULLET && item.type != EII_FORCED_GUN) {
      let actionBarType = g_hud_action_bar_type.getByActionItem(item)
      let killStreakTag = getTblValue("killStreakTag", item)
      let killStreakUnitTag = getTblValue("killStreakUnitTag", item)
      viewItem.icon <- actionBarType.getIcon(item, killStreakUnitTag)
      viewItem.cooldownIcon <- actionBarType.getCooldownIcon(item, killStreakUnitTag)
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

  function updateWaitGaugeDegree(obj, waitGaugeDegreeParams) {
    if (!obj)
      return
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
    this.actionItems = items.filter(@(action)
      !g_hud_action_bar_type.getByActionItem(action).isHidden())
    this.rawActionItems = items
    this.updateKillStreakWheel()

    if ((prevActionItems?.len() ?? 0) != this.actionItems.len() || this.actionItems.len() == 0) {
      this.openSecondActionsMenu(null)
      this.fill(prevActionItems)
      return
    }

    let hudUnitType = getHudUnitType()
    let unit = this.getActionBarUnit()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX

    local newActionWithMenu = this.currentActionWithMenu

    foreach (id, item in this.actionItems) {
      let prevItem = prevActionItems[id]
      if (!this.shouldForceUpdateItems && item == prevItem)
        continue

      if (newActionWithMenu == prevItem)
        newActionWithMenu = item?.isWaitSelectSecondAction ? item : null
      else if (item?.isWaitSelectSecondAction)
        newActionWithMenu = item

      if (this.cooldownTimers?[id])
        clearTimer(this.cooldownTimers[id])

      let itemObjId = getActionBarObjId(id)
      let nestActionObj = this.scene.findObject(itemObjId)
      if (!(nestActionObj?.isValid() ?? false))
        continue

      let { cooldownEndTime = 0, cooldownTime = 1, inProgressTime = 1, inProgressEndTime = 0,
        blockedCooldownEndTime = 0, blockedCooldownTime = 1, active = true, available = true } = item
      let cooldownTimeout = cooldownEndTime - get_mission_time()
      if (cooldownTimeout > 0)
        this.enableBarItemAfterCooldown(id, cooldownTimeout)

      if (this.shouldForceUpdateItems || needFullUpdate(item, prevItem, hudUnitType)) {
        let itemView = this.buildItemView(item, id, true)
        this.fillActionBarItem(nestActionObj, itemView)
        continue
      }

      let itemObj = nestActionObj.findObject("itemContent")
      let amountText = getActionItemAmountText(item)
      this.setItemAmountText(itemObj, amountText)
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
      itemObj.visualEnable = isReady ? "yes" : "no"
      if (item?.isWaitSelectSecondAction != prevItem?.isWaitSelectSecondAction ) {
        let collapseBtn = itemObj.findObject("actionCollapseBtn")
        if (collapseBtn != null)
          collapseBtn["rotation"] = item?.isWaitSelectSecondAction ? "180" : "0"
      }

      let mainActionButtonObj = itemObj.findObject("mainActionButton")
      let activatedActionButtonObj = itemObj.findObject("activatedActionButton")
      if (activatedActionButtonObj?.hasShortcut == "yes") {
        activatedActionButtonObj.show(active)
        mainActionButtonObj.top = active ? "h + 0.005@shHud" : "- h - 0.005@shHud"
      }

      let backgroundImage = actionBarType.getIcon(item, null, unit, hudUnitType)
      let iconObj = itemObj.findObject("action_icon")
      if ((iconObj?.isValid() ?? false) && backgroundImage.len() > 0)
        iconObj["background-image"] = backgroundImage
      if (actionType == EII_EXTINGUISHER)
        mainActionButtonObj.show(isReady)
      if (actionType == EII_ARTILLERY_TARGET && item.active != this.artillery_target_mode) {
        this.artillery_target_mode = item.active
        broadcastEvent("ArtilleryTarget", { active = this.artillery_target_mode })
      }

      let modifName = getActionItemModificationName(item, unit)
      if (modifName == null) 
        nestActionObj.findObject("tooltipLayer").tooltip = actionBarType.getTooltipText(item)

      let cooldownParams = available ? this.getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime)
        : notAvailableColdownParams

      this.updateWaitGaugeDegree(itemObj.findObject("cooldown"), cooldownParams)
      this.updateWaitGaugeDegree(itemObj.findObject("blockedCooldown"),
        this.getWaitGaugeDegreeParams(blockedCooldownEndTime, blockedCooldownTime))
      this.updateWaitGaugeDegree(itemObj.findObject("progressCooldown"),
        this.getWaitGaugeDegreeParams(inProgressEndTime, inProgressTime, !active))

      if (item.type == EII_SLAVE_UNIT_STATUS) {
        itemObj.findObject("unitIndex").setValue($"{item.innerIdx + 1}")
        itemObj.findObject("lockedIcon").show(item.available && !item.active)
      }
      if (itemObj.isHovered() || nestActionObj.isHovered())
        this.guiScene.updateTooltip(nestActionObj.findObject("tooltipLayer"))
    }

    if (this.shouldForceUpdateItems) {
      let extraItems = getExtraActionItemsView()
      foreach (itemView in extraItems) {
        let { id } = itemView
        let nestActionObj = this.scene.findObject(id)
        if (nestActionObj?.isValid())
          this.fillActionBarItem(nestActionObj, itemView)
      }
    }

    this.shouldForceUpdateItems = false
    this.openSecondActionsMenu(newActionWithMenu)
  }

  function updateExtraActionsAndMode() {
    this.extraActions = getExtraActionItemsView()
    this.extraActionsCount = this.extraActions.len()
    this.isWeaponSelectorMode = this.actionItems.len() == 0
      && this.extraActionsCount == 1
      && (this.extraActions[0]?.mainShortcutId ?? "") == WEAPON_SELECTOR_SHORTCUT_ID
  }

  function setItemAmountText(itemObject, amountText) {
    let amountTextObj = itemObject.findObject("amount_text")
    amountTextObj.setValue(amountText)
    amountTextObj.hudFont = shouldActionBarFontBeTiny(amountText) ? "tiny" : "small"
  }

  function enableBarItemAfterCooldown(itemIdx, timeout) {
    
    
    timeout += 0.5

    let cb = Callback(function() {
      let item = this.actionItems?[itemIdx]
      if (!item || !this.scene?.isValid())
        return
      let itemObjId = getActionBarObjId(itemIdx)
      let nestActionObj = this.scene.findObject(itemObjId)
      if (!nestActionObj?.isValid() || !getActionItemStatus(item).isReady)
        return
      let itemObj = nestActionObj.findObject("itemContent")
      itemObj.visualEnable = "yes"
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
    let canShowWithSelector = this.isWeaponSelectorMode && this.canControl && !this.isCollapsed
    let needHideSelector = isVisualHudAirWeaponSelectorOpened() && !canShowWithSelector
    this.isVisible = showActionBarOption && !g_hud_live_stats.isVisible() && !needHideSelector
    this.scene.show(this.isVisible)
    eventbus_send("setIsActionBarVisible", this.isVisible)
  }

  function activateAction(obj) {
    this.clearAutoCollapseTimer()
    let overrideClick = obj?.overrideClick ?? ""
    if (overrideClick != "" && overrideClick in this) {
      this[overrideClick](obj)
      return
    }
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
    let actionItemIdx = this.actionItems.findindex(@(a) a.id == action.id) ?? -1
    if (action?.additionalBulletInfo && actionItemIdx != -1) {
      let actionObjId = getActionBarObjId(actionItemIdx)
      let nestActionObj = this.scene.findObject(actionObjId)
      let actionObj = nestActionObj.findObject("itemContent")
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
    emulateShortcut(g_hud_action_bar_type.BULLET.getShortcut({shortcutIdx = obj.actionId.tointeger()}))
    updateActionBar()
  }

  function showSecondActions(obj, action = null) {
    action = action ?? this.getActionByObj(obj)

    if ((action?.additionalBulletInfo.len() ?? 0) == 0)
      return

    let secondItemsParams = this.generateSecondActions(action.additionalBulletInfo, action.triggerGroupNo)
    secondItemsParams.posx <- obj.getPos()[0]
    secondItemsParams.posy <- this.hasXInputSh ? this.getXInputShHeight() : this.getTextShHeight()

    let blk = handyman.renderCached(this.actionBarSecondItemsTpl, secondItemsParams)
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
    let actionItemNum = obj.actionId.tointeger()
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

    updateActionBar()
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
    foreach (idx, action in this.killStreaksActionsOrdered)
      menu.append(action != null ? this.buildItemView(action, idx) : null)

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
    foreach (item in this.rawActionItems)
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
    foreach (idx, action in this.weaponActions)
      menu.append(this.buildItemView(action, idx))
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

  function onActivateByShortcutId(obj) {
    let { shortcutId = "" } = obj
    if (shortcutId == "")
      return
    toggleShortcut(shortcutId)
  }

  onEventWeaponSelectorInit = @(_) get_cur_gui_scene()
    .performDelayed(this, this.syncWithWeaponSelector)

  onEventWeaponSelectorUserInteraction = @(_) this.clearAutoCollapseTimer()
}

let mkActionBarAir = @(nestObj) ActionBar(
  nestObj,
  "%gui/hud/actionBarItemAir.blk",
  "actionBarItemAirDiv"
)

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
  mkActionBarAir
}