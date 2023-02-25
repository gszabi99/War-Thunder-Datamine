//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_EXTINGUISHER, EII_ROCKET, EII_FORCED_GUN
} = require("hudActionBarConst")
let { arrangeStreakWheelActions } = require("%scripts/hud/hudActionBarStreakWheel.nut")
let { is_replay_playing } = require("replays")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { actionBarItems, updateActionBar } = require("%scripts/hud/actionBarState.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { get_game_type } = require("mission")

local sectorAngle1PID = ::dagui_propid.add_name_id("sector-angle-1")

let notAvailableColdownParams = { degree = 0, incFactor = 0 }

let function needFullUpdate(item, prevItem, hudUnitType) {
  return item.id != prevItem.id
    || (item.type != prevItem.type
       && ::g_hud_action_bar_type.getByActionItem(item).getShortcut(item, hudUnitType)
         != ::g_hud_action_bar_type.getByActionItem(prevItem).getShortcut(prevItem, hudUnitType))
    || (item?.isStreakEx && item.count < 0 && prevItem.count >= 0)
    || ((item.type == EII_BULLET || item.type == EII_FORCED_GUN)
       && item?.modificationName != prevItem?.modificationName)
    || ((item.type == EII_ROCKET) && item?.bulletName != prevItem?.bulletName)
}

::ActionBar <- class {
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

  __action_id_prefix = "action_bar_item_"

  isFootballMission = false

  constructor(nestObj) {
    if (!checkObj(nestObj))
      return
    this.scene     = nestObj
    this.guiScene  = nestObj.getScene()
    this.actionItems = []
    this.killStreaksActions = []
    this.weaponActions = []

    this.canControl = !::isPlayerDedicatedSpectator() && !is_replay_playing()

    this.isFootballMission = (get_game_type() & GT_FOOTBALL) != 0

    this.updateVisibility()

    ::g_hud_event_manager.subscribe("ToggleKillStreakWheel", function (eventData) {
      if ("open" in eventData)
        this.toggleKillStreakWheel(eventData.open)
    }, this)
    ::g_hud_event_manager.subscribe("ToggleSelectWeaponWheel", function (eventData) {
      if ("open" in eventData)
        this.toggleSelectWeaponWheel(eventData.open)
    }, this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled", function (_eventData) {
      this.updateVisibility()
    }, this)
    ::g_hud_event_manager.subscribe("LocalPlayerAlive", function (_data) {
      updateActionBar()
    }, this)

    this.updateParams()
    updateActionBar()
    this.scene.setValue(stashBhvValueConfig([{
      watch = actionBarItems
      updateFunc = Callback(@(_obj, actionItems) this.updateActionBarItems(actionItems), this)
    }]))
  }

  function reinit() {
    this.updateParams()
    updateActionBar()
  }

  function updateParams() {
    this.useWheelmenu = ::have_xinput_device()
  }

  function isValid() {
    return checkObj(this.scene)
  }

  function getActionBarUnit() {
    return ::getAircraftByName(getActionBarUnitName())
  }

  function fill() {
    if (!checkObj(this.scene))
      return

    this.curActionBarUnitName = getActionBarUnitName()

    let view = {
      items = ::u.map(this.actionItems, (@(a) this.buildItemView(a, true)).bindenv(this))
    }

    let partails = {
      items           = loadTemplateText("%gui/hud/actionBarItem.tpl")
      textShortcut    = this.canControl ? loadTemplateText("%gui/hud/actionBarItemTextShortcut.tpl")    : ""
      gamepadShortcut = this.canControl ? loadTemplateText("%gui/hud/actionBarItemGamepadShortcut.tpl") : ""
    }
    let blk = ::handyman.renderCached(("%gui/hud/actionBar.tpl"), view, partails)
    this.guiScene.replaceContentFromText(this.scene.findObject("actions_nest"), blk, blk.len(), this)
    this.scene.findObject("action_bar").setUserData(this)

    ::broadcastEvent("HudActionbarInited", { actionBarItemsAmount = this.actionItems.len() })
  }

  //creates view for handyman by one actionBar item
  function buildItemView(item, needShortcuts = false) {
    let hudUnitType = getHudUnitType()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX

    let actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
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

      let shType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
      let scInput = shType.getFirstInput(shortcutId)
      shortcutText = scInput.getText()
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
      id               = this.__action_id_prefix + item.id
      selected         = item.selected ? "yes" : "no"
      active           = item.active ? "yes" : "no"
      enable           = isReady ? "yes" : "no"
      wheelmenuEnabled = isReady || actionBarType.canSwitchAutomaticMode()
      shortcutText     = shortcutText
      isLongScText     = ::utf8_strlen(shortcutText) >= LONG_ACTIONBAR_TEXT_LEN
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
    }

    let unit = this.getActionBarUnit()
    let modifName = getActionItemModificationName(item, unit)
    if (modifName) {
      viewItem.bullets <- ::handyman.renderNested(loadTemplateText("%gui/weaponry/bullets.tpl"),
        function (_text) {
          // if fake bullets are not generated yet, generate them
          if (isFakeBullet(modifName) && !(modifName in unit.bulletsSets))
            getBulletsSetData(unit, ::fakeBullets_prefix, {})
          let data = getBulletsSetData(unit, modifName)
          return getBulletsIconView(data)
        }
      )
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

    return viewItem
  }

  function getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime, isReverse = false) {
    let res = { degree = 360, incFactor = 0 }
    let cooldownDuration = cooldownEndTime - ::get_usefull_total_time()
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
    let { degree, incFactor } = waitGaugeDegreeParams
    if (degree == (obj.getFinalProp(sectorAngle1PID) ?? -1).tointeger())
      return
    obj["inc-factor"] = format("%.1f", incFactor)
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
      this.fill()
      ::broadcastEvent("HudActionbarResized", { size = this.actionItems.len() })
      return
    }

    let hudUnitType = getHudUnitType()
    let unit = this.getActionBarUnit()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX
    foreach (id, item in this.actionItems) {
      let prevItem = prevActionItems[id]
      if (item == prevItem)
        continue

      if (needFullUpdate(item, prevItem, hudUnitType)) {
        this.fill()
        return
      }

      let itemObjId = $"{this.__action_id_prefix}{item.id}"
      let itemObj = this.scene.findObject(itemObjId)
      if (!(itemObj?.isValid() ?? false))
        continue

      itemObj.findObject("amount_text").setValue(getActionItemAmountText(item))
      itemObj.findObject("automatic_text")?.show(ship && item?.automatic)

      let actionType = item.type
      let { isReady } = getActionItemStatus(item)
      if (actionType != EII_BULLET && !itemObj.isEnabled() && isReady)
        this.blink(itemObj)

      let actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
      if (actionBarType.needAnimOnIncrementCount)
        this.handleIncrementCount(item, prevActionItems[id], itemObj)

      itemObj.selected = item.selected ? "yes" : "no"
      itemObj.active = item.active ? "yes" : "no"
      itemObj.enable(isReady)

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
        ::broadcastEvent("ArtilleryTarget", { active = this.artillery_target_mode })
      }

      if (actionType != prevActionItems[id].type)
        this.scene.findObject($"tooltip_{itemObjId}").tooltip = actionBarType.getTooltipText(item)

      let { cooldownEndTime = 0, cooldownTime = 1, inProgressTime = 1, inProgressEndTime = 0,
        blockedCooldownEndTime = 0, blockedCooldownTime = 1, active = true, available = true } = item
      let cooldownParams = available ? this.getWaitGaugeDegreeParams(cooldownEndTime, cooldownTime)
        : notAvailableColdownParams
      this.updateWaitGaugeDegree(itemObj.findObject("cooldown"), cooldownParams)
      this.updateWaitGaugeDegree(itemObj.findObject("blockedCooldown"),
        this.getWaitGaugeDegreeParams(blockedCooldownEndTime, blockedCooldownTime))
      this.updateWaitGaugeDegree(itemObj.findObject("progressCooldown"),
        this.getWaitGaugeDegreeParams(inProgressEndTime, inProgressTime, !active))
    }
  }

  /**
   * Function checks increase count and shows it in view.
   * It needed for display rearming process.
   */
  function handleIncrementCount(currentItem, prewItem, itemObj) {
    if ((prewItem.countEx == currentItem.countEx && prewItem.count < currentItem.count)
      || (prewItem.countEx < currentItem.countEx)
      || (prewItem.ammoLost < currentItem.ammoLost)) {
      let delta = currentItem.countEx - prewItem.countEx || currentItem.count - prewItem.count
      if (prewItem.ammoLost < currentItem.ammoLost)
        ::g_hud_event_manager.onHudEvent("hint:ammoDestroyed:show")
      let blk = ::handyman.renderCached("%gui/hud/actionBarIncrement.tpl", { is_increment = delta > 0, delta_amount = delta })
      this.guiScene.appendWithBlk(itemObj, blk, this)
    }
  }

  function blink(obj) {
    let blinkObj = obj.findObject("availability")
    if (checkObj(blinkObj))
      blinkObj["_blink"] = "yes"
  }

  function updateVisibility() {
    if (checkObj(this.scene))
      this.scene.show(!::g_hud_live_stats.isVisible())
  }

  function activateAction(obj) {
    let action = this.getActionByObj(obj)
    if (action) {
      let shortcut = ::g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
      if (shortcut)
        toggleShortcut(shortcut)
    }
  }

  //Only for streak wheel menu
  function activateStreak(streakId) {
    let action = this.killStreaksActionsOrdered?[streakId]
    if (action)
      return activateActionBarAction(action.shortcutIdx)

    if (streakId >= 0) { //something goes wrong; -1 is valid situation = player does not choose smthng
      debugTableData(this.killStreaksActionsOrdered)
      debug_dump_stack()
      assert(false, "Error: killStreak id out of range.")
    }
  }

  function activateWeapon(streakId) {
    let action = getTblValue(streakId, this.weaponActions)
    if (action) {
      let shortcut = ::g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
      toggleShortcut(shortcut)
    }
  }


  function getActionByObj(obj) {
    let actionItemNum = obj.id.slice(-(obj.id.len() - this.__action_id_prefix.len())).tointeger()
    foreach (item in this.actionItems)
      if (item.id == actionItemNum)
        return item
    return null
  }

  function toggleKillStreakWheel(open) {
    if (!checkObj(this.scene))
      return

    if (open) {
      if (this.killStreaksActions.len() == 1) {
        this.guiScene.performDelayed(this, function() {
          activateActionBarAction(this.killStreaksActions[0].shortcutIdx)
          ::close_cur_wheelmenu()
        })
      }
      else
        this.openKillStreakWheel()
    }
    else
      ::close_cur_wheelmenu()
  }

  function openKillStreakWheel() {
    if (!this.useWheelmenu)
      return

    this.updateKillStreaksActions()
    if (this.killStreaksActions.len() == 0)
      return

    ::close_cur_voicemenu()

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

    ::gui_start_wheelmenu(params, isUpdate)
  }

  function updateKillStreaksActions() {
    this.killStreaksActions = []
    foreach (item in this.actionItems)
      if (::g_hud_action_bar_type.getByActionItem(item).isForWheelMenu())
        this.killStreaksActions.append(item)
  }

  function updateKillStreakWheel() {
    if (!this.useWheelmenu)
      return

    let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.wheelMenuHandler)
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
      if (::g_hud_action_bar_type.getByActionItem(item).isForSelectWeaponMenu())
        this.weaponActions.append(item)
  }

  function toggleSelectWeaponWheel(open) {
    if (!checkObj(this.scene))
      return

    if (open)
      this.fillSelectWaponWheel()
    else
      ::close_cur_wheelmenu()
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
    ::gui_start_wheelmenu(params)
  }
  function onTooltipObjClose(obj) {
    ::g_tooltip.close.call(this, obj)
  }

  function onGenericTooltipOpen(obj) {
    ::g_tooltip.open(obj, this)
  }
}
