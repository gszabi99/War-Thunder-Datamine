from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { debug_dump_stack } = require("dagor.debug")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file(v))
let { isFakeBullet, getBulletsSetData } = require("%scripts/weaponry/bulletsInfo.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")
let { MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { LONG_ACTIONBAR_TEXT_LEN, getActionItemAmountText, getActionItemModificationName
} = require("%scripts/hud/hudActionBarInfo.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getActionBarItems, getWheelBarItems, activateActionBarAction,
  getActionBarUnitName } = require_native("hudActionBar")
let { EII_BULLET, EII_ARTILLERY_TARGET, EII_EXTINGUISHER, EII_ROCKET, EII_FORCED_GUN
} = require_native("hudActionBarConst")
let { arrangeStreakWheelActions } = require("%scripts/hud/hudActionBarStreakWheel.nut")
let { is_replay_playing } = require("replays")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")

local sectorAngle1PID = ::dagui_propid.add_name_id("sector-angle-1")

::ActionBar <- class
{
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
    this.killStreaksActions = []
    this.weaponActions = []

    this.canControl = !::isPlayerDedicatedSpectator() && !is_replay_playing()

    this.isFootballMission = (::get_game_type() & GT_FOOTBALL) != 0

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
      this.fill() //the same unit can change bullets order.
    }, this)

    this.updateParams()
    this.fill()
  }

  function reinit(forceUpdate = false)
  {
    this.updateParams()
    if (forceUpdate || getActionBarUnitName() != this.curActionBarUnitName)
      this.fill()
    else
      this.onUpdate()
  }

  function updateParams()
  {
    this.useWheelmenu = ::have_xinput_device()
  }

  function isValid()
  {
    return checkObj(this.scene)
  }

  function getActionBarUnit()
  {
    return ::getAircraftByName(getActionBarUnitName())
  }

  function fill()
  {
    if (!checkObj(this.scene))
      return

    this.curActionBarUnitName = getActionBarUnitName()
    this.actionItems = this.getActionBar()

    let view = {
      items = ::u.map(this.actionItems, (@(a) this.buildItemView(a, true)).bindenv(this))
    }

    let partails = {
      items           = loadTemplateText("%gui/hud/actionBarItem.tpl")
      textShortcut    = this.canControl ? loadTemplateText("%gui/hud/actionBarItemTextShortcut.tpl")    : ""
      gamepadShortcut = this.canControl ? loadTemplateText("%gui/hud/actionBarItemGamepadShortcut.tpl") : ""
    }
    let blk = ::handyman.renderCached(("%gui/hud/actionBar.tpl"), view, partails)
    this.guiScene.replaceContentFromText(this.scene, blk, blk.len(), this)
    this.scene.findObject("action_bar").setUserData(this)

    ::broadcastEvent("HudActionbarInited", { actionBarItemsAmount = this.actionItems.len() })
  }

  //creates view for handyman by one actionBar item
  function buildItemView(item, needShortcuts = false)
  {
    let hudUnitType = getHudUnitType()
    let actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
    let isReady = this.isActionReady(item)

    local shortcutText = ""
    local isXinput = false
    local shortcutId = ""
    local showShortcut = false
    if (needShortcuts && actionBarType.getShortcut(item, hudUnitType))
    {
      shortcutId = actionBarType.getVisualShortcut(item, hudUnitType)

      if (this.isFootballMission)
        shortcutId = item?.modificationName == "152mm_football" ? "ID_FIRE_GM"
          : item?.modificationName == "152mm_football_jump" ? "ID_FIRE_GM_MACHINE_GUN"
          : shortcutId

      let shType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
      let scInput = shType.getFirstInput(shortcutId)
      shortcutText = scInput.getText()
      isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
      showShortcut = isXinput || shortcutText !=""
    }

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
      cooldown         = this.getWaitGaugeDegree(item.cooldown)
    }

    let unit = this.getActionBarUnit()
    let modifName = getActionItemModificationName(item, unit)
    if (modifName)
    {
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
    else if (item.type == EII_ARTILLERY_TARGET)
    {
      viewItem.activatedShortcutId <- "ID_SHOOT_ARTILLERY"
    }

    if (!modifName && item.type != EII_BULLET && item.type != EII_FORCED_GUN)
    {
      let killStreakTag = getTblValue("killStreakTag", item)
      let killStreakUnitTag = getTblValue("killStreakUnitTag", item)
      viewItem.icon <- actionBarType.getIcon(item, killStreakUnitTag)
      viewItem.name <- actionBarType.getTitle(item, killStreakTag)
      viewItem.tooltipText <- actionBarType.getTooltipText(item)
    }

    return viewItem
  }

  function isActionReady(action)
  {
    return action.cooldown <= 0
  }

  function getWaitGaugeDegree(val)
  {
    return (360 - (clamp(val, 0.0, 1.0) * 360)).tointeger()
  }

  function updateWaitGaugeDegree(obj, val) {
    let degree = this.getWaitGaugeDegree(val)
    if (degree == (obj.getFinalProp(sectorAngle1PID) ?? -1).tointeger())
      return
    obj.set_prop_latent(sectorAngle1PID, degree)
    obj.updateRendElem()
  }

  function onUpdate(_obj = null, _dt = 0.0)
  {
    let prevCount = type(this.actionItems) == "array" ? this.actionItems.len() : 0
    let prevKillStreaksActions = this.killStreaksActions

    let prevActionItems = this.actionItems
    this.actionItems = this.getActionBar()

    if (this.useWheelmenu)
      this.updateKillStreakWheel(prevKillStreaksActions)

    local fullUpdate = prevCount != this.actionItems.len()
    if (!fullUpdate)
    {
      foreach (id, item in this.actionItems)
        if (item.id != prevActionItems[id].id
          || item.type != prevActionItems[id].type
          || (item?.isStreakEx && item.count < 0 && prevActionItems[id].count >= 0)
          || ((item.type == EII_BULLET || item.type == EII_FORCED_GUN)
            && item?.modificationName != prevActionItems[id]?.modificationName)
          || ((item.type == EII_ROCKET)
            && item?.bulletName != prevActionItems[id]?.bulletName))
        {
          fullUpdate = true
          break
        }
    }

    if (fullUpdate)
    {
      this.fill()
      ::broadcastEvent("HudActionbarResized", { size = this.actionItems.len() })
      return
    }

    let hudUnitType = getHudUnitType()
    let ship = hudUnitType == HUD_UNIT_TYPE.SHIP
      || hudUnitType == HUD_UNIT_TYPE.SHIP_EX
    foreach(item in this.actionItems)
    {
      let itemObj = this.scene.findObject(this.__action_id_prefix + item.id)
      if (!checkObj(itemObj))
        continue

      let amountObj = itemObj.findObject("amount_text")
      if (checkObj(amountObj))
        amountObj.setValue(getActionItemAmountText(item))

      let automaticObj = itemObj.findObject("automatic_text")
      if (checkObj(automaticObj))
        automaticObj.show(ship && item?.automatic)

      if (item.type != EII_BULLET && !itemObj.isEnabled() && this.isActionReady(item))
        this.blink(itemObj)

      this.handleIncrementCount(item, prevActionItems, itemObj)

      itemObj.selected = item.selected ? "yes" : "no"
      itemObj.active = item.active ? "yes" : "no"
      itemObj.enable(this.isActionReady(item))

      let mainActionButtonObj = itemObj.findObject("mainActionButton")
      let activatedActionButtonObj = itemObj.findObject("activatedActionButton")
      let cancelButtonObj = itemObj.findObject("cancelButton")
      if (checkObj(mainActionButtonObj) &&
          checkObj(activatedActionButtonObj) &&
          checkObj(cancelButtonObj))
      {
          mainActionButtonObj.show(!item.active)
          activatedActionButtonObj.show(item.active)
          cancelButtonObj.show(item.active)
      }

      let actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
      let backgroundImage = actionBarType.getIcon(item)
      let iconObj = itemObj.findObject("action_icon")
      if (checkObj(iconObj))
      {
        if (backgroundImage.len() > 0)
          iconObj["background-image"] = backgroundImage
      }
      if (item.type == EII_EXTINGUISHER && checkObj(mainActionButtonObj))
        mainActionButtonObj.show(item.cooldown == 0)
      if (item.type == EII_ARTILLERY_TARGET && item.active != this.artillery_target_mode)
      {
        this.artillery_target_mode = item.active
        ::broadcastEvent("ArtilleryTarget", { active = this.artillery_target_mode })
      }

      this.updateWaitGaugeDegree(itemObj.findObject("cooldown"), item.cooldown)
      this.updateWaitGaugeDegree(itemObj.findObject("blockedCooldown"), item?.blockedCooldown ?? 0.0)
    }
  }

  /**
   * Function checks increase count and shows it in view.
   * It needed for display rearming process.
   */
  function handleIncrementCount(currentItem, prewItemsArray, itemObj)
  {
    let actionBarType = ::g_hud_action_bar_type.getByActionItem(currentItem)
     if (!actionBarType.needAnimOnIncrementCount)
       return

    let prewItem = ::u.search(prewItemsArray, (@(currentItem) function (searchItem) {
      return currentItem.id == searchItem.id
    })(currentItem))

    if (prewItem == null)
      return

    if ((prewItem.countEx == currentItem.countEx && prewItem.count < currentItem.count)
      || (prewItem.countEx < currentItem.countEx)
      || (prewItem.ammoLost < currentItem.ammoLost))
    {
      let delta = currentItem.countEx - prewItem.countEx || currentItem.count - prewItem.count
      if (prewItem.ammoLost < currentItem.ammoLost)
        ::g_hud_event_manager.onHudEvent("hint:ammoDestroyed:show")
      let blk = ::handyman.renderCached("%gui/hud/actionBarIncrement.tpl", {is_increment = delta > 0, delta_amount = delta})
      this.guiScene.appendWithBlk(itemObj, blk, this)
    }
  }

  function blink(obj)
  {
    let blinkObj = obj.findObject("availability")
    if (checkObj(blinkObj))
      blinkObj["_blink"] = "yes"
  }

  function updateVisibility()
  {
    if (checkObj(this.scene))
      this.scene.show(!::g_hud_live_stats.isVisible())
  }

  /* *
   * Wrapper for getActionBarItems().
   * Need to separate killstreak reward form other
   * action bar items.
   * Works only with gamepad controls.
   * */
  function getActionBar()
  {
    let hudUnitType = getHudUnitType()
    let isUnitValid = hudUnitType != ""
    let rawActionBarItem = isUnitValid ? getActionBarItems() : []
    if (!this.useWheelmenu)
      return rawActionBarItem

    let rawWheelItem = isUnitValid ? (getWheelBarItems() ?? []) : []
    this.killStreaksActions = []
    this.weaponActions = []
    for (local i = rawActionBarItem.len() - 1; i >= 0; i--)
    {
      let actionBarType = ::g_hud_action_bar_type.getByActionItem(rawActionBarItem[i])
      if (actionBarType.isForWheelMenu())
        this.killStreaksActions.append(rawActionBarItem[i])
    }
    for (local i = rawWheelItem.len() - 1; i >= 0; i--)
    {
      let actionBarType = ::g_hud_action_bar_type.getByActionItem(rawWheelItem[i])
      if (actionBarType.isForSelectWeaponMenu())
        this.weaponActions.insert(0, rawWheelItem[i])
    }

    return rawActionBarItem
  }

  function activateAction(obj)
  {
    let action = this.getActionByObj(obj)
    if (action)
    {
      let shortcut = ::g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
      if (shortcut)
        toggleShortcut(shortcut)
    }
  }

  //Only for streak wheel menu
  function activateStreak(streakId)
  {
    let action = this.killStreaksActionsOrdered?[streakId]
    if (action)
      return activateActionBarAction(action.shortcutIdx)

    if (streakId >= 0) //something goes wrong; -1 is valid situation = player does not choose smthng
    {
      debugTableData(this.killStreaksActionsOrdered)
      debug_dump_stack()
      assert(false, "Error: killStreak id out of range.")
    }
  }

  function activateWeapon(streakId)
  {
    let action = getTblValue(streakId, this.weaponActions)
    if (action)
    {
      let shortcut = ::g_hud_action_bar_type.getByActionItem(action).getShortcut(action, getHudUnitType())
      toggleShortcut(shortcut)
    }
  }


  function getActionByObj(obj)
  {
    let actionItemNum = obj.id.slice(-(obj.id.len() - this.__action_id_prefix.len())).tointeger()
    foreach (item in this.actionItems)
      if (item.id == actionItemNum)
        return item
    return null
  }

  function toggleKillStreakWheel(open)
  {
    if (!checkObj(this.scene))
      return

    if (open)
    {
      if (this.killStreaksActions.len() == 1)
      {
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

  function openKillStreakWheel()
  {
    if (!this.killStreaksActions || this.killStreaksActions.len() == 0)
      return

    ::close_cur_voicemenu()

    this.fillKillStreakWheel()
  }

  function fillKillStreakWheel(isUpdate = false)
  {
    this.killStreaksActionsOrdered = arrangeStreakWheelActions(getActionBarUnitName(),
      getHudUnitType(), this.killStreaksActions)

    let menu = []
    foreach(action in this.killStreaksActionsOrdered)
      menu.append(action != null ? this.buildItemView(action) : null)

    let params = {
      menu            = menu
      callbackFunc    = this.activateStreak
      contentTemplate = "%gui/hud/actionBarItemStreakWheel.tpl"
      owner           = this
    }

    ::gui_start_wheelmenu(params, isUpdate)
  }

  function updateKillStreakWheel(prevActions)
  {
    let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.wheelMenuHandler)
    if (!handler || !handler.isActive)
      return

    local update = false
    if (this.killStreaksActions.len() != prevActions.len())
      update = true
    else
    {
      for (local i = this.killStreaksActions.len() - 1; i >= 0; i--)
        if (this.killStreaksActions[i].active != prevActions[i].active ||
          this.isActionReady(this.killStreaksActions[i]) != this.isActionReady(prevActions[i]) ||
          this.killStreaksActions[i].count != prevActions[i].count ||
          this.killStreaksActions[i].countEx != prevActions[i].countEx)
        {
          update = true
          break
        }
    }

    if (update)
      this.fillKillStreakWheel(true)
  }

  function toggleSelectWeaponWheel(open)
  {
    if (!checkObj(this.scene))
      return

    if (open)
      this.fillSelectWaponWheel()
    else
      ::close_cur_wheelmenu()
  }

  function fillSelectWaponWheel()
  {
    let menu = []
    foreach(action in this.weaponActions)
      menu.append(this.buildItemView(action))
    let params = {
      menu            = menu
      callbackFunc    = this.activateWeapon
      contentTemplate = "%gui/hud/actionBarItemStreakWheel.tpl"
      owner           = this
    }
    ::gui_start_wheelmenu(params)
  }
  function onTooltipObjClose(obj)
  {
    ::g_tooltip.close.call(this, obj)
  }

  function onGenericTooltipOpen(obj)
  {
    ::g_tooltip.open(obj, this)
  }
}
