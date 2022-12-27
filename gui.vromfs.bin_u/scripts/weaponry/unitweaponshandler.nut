from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { updateModItem,
        createModItemLayout,
        updateItemBulletsSlider } = require("%scripts/weaponry/weaponryVisual.nut")
        let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { ceil } = require("math")

let { getLastWeapon, setLastWeapon, isWeaponEnabled, isWeaponVisible,
  isDefaultTorpedoes } = require("%scripts/weaponry/weaponryInfo.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitStatus.nut")

::gui_handlers.unitWeaponsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  unit = null
  canShowPrice = false
  canChangeWeaponry = true
  canChangeBulletsAmount = true

  weaponItemId = "secondary_weapon"
  bulletsIdPrefix = "bullets_"
  headerOffset = 0.3

  bulletsManager = null
  modsInRow = 3
  needRecountWidth = true

  showItemParams = null
  isForcedAvailable = false
  forceShowDefaultTorpedoes = false

  function initScreen()
  {
    this.bulletsManager = ::UnitBulletsManager(this.unit, { isForcedAvailable = this.isForcedAvailable })
    this.updateShowItemParams()
    this.setUnit(this.unit, true)
  }

  function checkInitWidth()
  {
    if (!this.needRecountWidth || !this.scene.isVisible() || this.scene.getSize()[0] <= 0)
      return

    let sizes = ::g_dagui_utils.countSizeInItems(this.scene, "@modCellWidth", "@modCellHeight", 0, 0)
    this.modsInRow = sizes.itemsCountX
    this.scene.width = this.modsInRow + "@modCellWidth"
    this.needRecountWidth = false
  }

  function updateShowItemParams()
  {
    this.showItemParams = {
      canShowPrice = this.canShowPrice
      canShowStatusImage = false
      selectBulletsByManager = (this.canChangeWeaponry && this.canChangeBulletsAmount) ? this.bulletsManager : null
      needSliderButtons = this.canChangeBulletsAmount
      hasMenu = false
      isForceHidePlayerInfo = this.isForcedAvailable || this.forceShowDefaultTorpedoes
    }
  }

  function setUnit(newUnit, forceUpdate = false)
  {
    if (!forceUpdate && this.unit == newUnit)
      return

    this.checkInitWidth()
    this.unit = newUnit
    this.bulletsManager.setUnit(this.unit)

    local columnsConfig = null
    let unitType = ::get_es_unit_type(this.unit)
    if (isInArray(unitType, [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]))
      columnsConfig = this.getColumnsAircraft()
    else if (unitType == ES_UNIT_TYPE_TANK || unitType == ES_UNIT_TYPE_SHIP || unitType == ES_UNIT_TYPE_BOAT)
      columnsConfig = this.getColumnsTank()

    if (!columnsConfig)
    {
      this.clearScene()
      return
    }

    this.fillWeaponryByColumnsConfig(columnsConfig)
    this.updateAllItems()
  }

  function setCanChangeWeaponry(newValue, forceUpdate)
  {
    if (newValue == this.canChangeWeaponry && !forceUpdate)
      return

    this.canChangeWeaponry = newValue
    this.updateShowItemParams()
    if(!this.unit)
      return

    this.updateAllItems()
  }

  /*
    columnsConfig = {
      itemWidth = 1
      columns = [  //len <= modsInRow / width
        [
          { id = "string"
            header = "string"  //optional
            itemType = weaponsItem.unknown
            bulGroupIdx = int  //only for bullets
          }
        ]
        ...
      ]
    }
  */
  function fillWeaponryByColumnsConfig(config)
  {
    let view = {
      bgBlocks = []
      weaponryList = ""
    }

    let itemWidth = config.itemWidth
    let columns = config.columns

    local isLineEmpty = false
    local lineOffset = 0.0
    local lastBgBlock = null
    local line = 0
    for(; !isLineEmpty; line++)
    {
      isLineEmpty = true
      local needHeader = false
      local bgBlock = this.getBgBlockBaseTemplate(itemWidth * columns.len())

      let cellsRow = array(columns.len(), null)
      foreach(idx, column in columns)
      {
        let cell = getTblValue(line, column)
        if ((!cell || !cell.header) && bgBlock.columnsList.len())
          bgBlock.columnsList[bgBlock.columnsList.len() - 1].width += itemWidth

        if (!cell || cell.itemType == weaponsItem.unknown)
          continue

        cellsRow[idx] = cell

        isLineEmpty = false
        if (!needHeader)
          bgBlock.offsetX = itemWidth * idx
        needHeader = needHeader || cell.header != null

        if (cell.header)
          bgBlock.columnsList.append(this.getColumnConfig(cell.header, bgBlock.columnsList.len() > 0, itemWidth))
      }

      if (isLineEmpty)
        break

      if (needHeader)
      {
        lineOffset += this.headerOffset
        bgBlock.offsetY = lineOffset + line
        view.bgBlocks.append(bgBlock)
        lastBgBlock = bgBlock
      } else if (lastBgBlock)
      {
        bgBlock = lastBgBlock
        bgBlock.height++
      }

      bgBlock.rows.append(
      {
        width = itemWidth * columns.len() - bgBlock.offsetX
        top = bgBlock.rows.len()
      })

      view.weaponryList += this.addItemsByCellsRow(cellsRow, lineOffset + line, itemWidth)
    }

    this.scene.height = (lineOffset + line) + "@modCellHeight"
    if (!this.needRecountWidth)
      this.scene.width = (itemWidth * columns.len()) + "@modCellWidth"
    let data = ::handyman.renderCached("%gui/weaponry/weaponry.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getBgBlockBaseTemplate(width)
  {
    return {
      width = width
      height = 1
      offsetX = 0
      offsetY = 0
      headerClass = "tiny"
      columnsList = []
      rows = []
    }
  }

  function getColumnConfig(header, needDivLine = false, width = 1)
  {
    return {
      name = header
      needDivLine = needDivLine
      width = width
      isSmallFont = true
    }
  }

  function addItemsByCellsRow(cellsRow, offsetY, itemWidth = 1)
  {
    local res = ""
    let params = {
      posX = 0
      posY = offsetY
      itemWidth = itemWidth
      needSliderButtons = true
      wideItemWithSlider = itemWidth > 1
    }
    foreach(idx, cell in cellsRow)
    {
      if (!cell)
        continue

      params.posX = itemWidth * idx
      local item = null
      if (cell.itemType == weaponsItem.weapon)
        item = this.getCurWeapon()
      else if (cell.itemType == weaponsItem.modification)
        item = this.getCurBullet(cell.bulGroupIdx)

      if (item)
        res += createModItemLayout(cell.id, this.unit, item, cell.itemType, params)
    }
    return res
  }

  function getBulletsItemId(groupIdx)
  {
    return this.bulletsIdPrefix + groupIdx
  }

  function getCellConfig(id = "", header = null, itemType = weaponsItem.unknown, bulGroupIdx = 0)
  {
    return {
      id = id
      header = header
      itemType = itemType
      bulGroupIdx = bulGroupIdx
    }
  }

  function getEmptyColumnsConfig()
  {
    return {
      itemWidth = 1
      columns = []
    }
  }

  function getColumnsAircraft()
  {
    let res = this.getEmptyColumnsConfig()
    if (isUnitHaveSecondaryWeapons(this.unit))
      res.columns.append([this.getCellConfig(this.weaponItemId, ::g_weaponry_types.WEAPON.getHeader(this.unit), weaponsItem.weapon)])

    let groups = this.getBulletsGroups()
    let offset = res.columns.len() < this.modsInRow ? res.columns.len() : 0
    let totalColumns = min(offset + groups.len(), this.modsInRow)
    for(local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])

    foreach(gIdx, bulGroup in groups)
    {
      let col = offset + (gIdx % (totalColumns - offset))
      res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), bulGroup.getHeader(), weaponsItem.modification, gIdx))
    }

    return res
  }

  function getColumnsTank()
  {
    let groups = this.getBulletsGroups()
    let gunsCount = this.bulletsManager.getGunTypesCount()
    if (!gunsCount)
      return null

    let res = this.getEmptyColumnsConfig()
    if (this.canChangeBulletsAmount)
      res.itemWidth = 1.5
    if (gunsCount == 1)
    {
      let totalMods = this.bulletsManager.getActiveBulGroupsAmount()
      local totalColumns = 0

      if (totalMods > 0)
      {
        let totalRows = ceil(totalMods.tofloat() / this.modsInRow * res.itemWidth).tointeger()
        totalColumns = ceil(totalMods.tofloat() / totalRows).tointeger()
      }

      for(local i = res.columns.len(); i < totalColumns; i++)
        res.columns.append([])
      foreach(gIdx, bulGroup in groups)
      {
        if (!bulGroup.active || bulGroup.shouldHideBullet())
          continue
        let col = gIdx % totalColumns
        let header = !gIdx ? bulGroup.getHeader() : null
        res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
      }
      return this.addSecondaryWeaponToTankColumns(res)
    }

    local totalColumns = gunsCount
    for(local i = res.columns.len(); i < totalColumns; i++)
      res.columns.append([])
    foreach(gIdx, bulGroup in groups)
    {
      if (!bulGroup.active || bulGroup.shouldHideBullet())
        continue
      let col = bulGroup.getGunIdx()
      let header = !res.columns[col].len() ? bulGroup.getHeader() : null
      res.columns[col].append(this.getCellConfig(this.getBulletsItemId(gIdx), header, weaponsItem.modification, gIdx))
    }

    let maxColumns = (this.modsInRow / res.itemWidth) || 1
    if (gunsCount == 3 && maxColumns == 2)
    {
      let newColumns = [[], []]
      local singleItemIdx = -1
      foreach(idx, column in res.columns)
      {
        if (column.len() > 1)
        {
          newColumns[0].append(column[0])
          newColumns[1].append(column[1])
        } else if (singleItemIdx == -1)
        {
          newColumns[0].append(column[0])
          newColumns[1].append(null)
          singleItemIdx = idx
        } else if (column.len() != 0)
          newColumns[1][singleItemIdx] = column[0]
      }
      res.columns = newColumns
      totalColumns = 2
    }

    if (maxColumns < totalColumns)
      for(local i = res.columns.len() - 1; i >= maxColumns; i--)
      {
        res.columns[i % maxColumns].extend(res.columns[i])
        res.columns.remove(i)
      }

    return this.addSecondaryWeaponToTankColumns(res)
  }

  function addSecondaryWeaponToTankColumns(colData)
  {
    if (!isUnitHaveSecondaryWeapons(this.unit))
      return colData

    let weaponCell = this.getCellConfig(this.weaponItemId, ::g_weaponry_types.WEAPON.getHeader(this.unit), weaponsItem.weapon)
    let maxColumns = (this.modsInRow / colData.itemWidth) || 1
    if (colData.columns.len() < maxColumns)
      colData.columns.insert(0, [weaponCell])
    else
      foreach(idx, column in colData.columns)
        column.insert(0, idx ? null : weaponCell)
    return colData
  }

  function clearScene()
  {
    this.scene.height = "0"
    this.guiScene.replaceContentFromText(this.scene, "", 0, this)
  }

  function getCurWeapon()
  {
    local defWeapon = null
    let weaponName = getLastWeapon(this.unit.name)
    foreach(weapon in this.unit.getWeapons())
    {
      let found = weapon.name == weaponName
      //no point to check all weapons visibility and counts when we need only one
      if (!found && defWeapon)
        continue

      if (!this.isForcedAvailable
          && (!this.forceShowDefaultTorpedoes || !isDefaultTorpedoes(weapon))
          && (!isWeaponVisible(this.unit, weapon) || !isWeaponEnabled(this.unit, weapon)))
        continue

      if (found)
        return weapon

      if (!defWeapon)
        defWeapon = weapon
    }
    if (defWeapon) //validate selected weapon
      this.setWeapon(defWeapon.name)
    return defWeapon
  }

  function setWeapon(name) {
    setLastWeapon(this.unit.name, name)
  }

  function hasWeaponsToChooseFrom()
  {
    local count = 0
    let hasOnlySelectable = !::is_in_flight() || !::g_mis_custom_state.getCurMissionRules().isWorldWar
    foreach(weapon in this.unit.getWeapons())
    {
      if (!this.isForcedAvailable
          && (!this.forceShowDefaultTorpedoes || !isDefaultTorpedoes(weapon))
          && !isWeaponVisible(this.unit, weapon, hasOnlySelectable))
        continue

      count++
      if (count > 1)
        return true
    }
    return false
  }

  getBulletsGroups = @() this.bulletsManager.getBulletsGroups()
  getBulletGroupByIndex = @(groupIdx) this.getBulletsGroups()?[groupIdx]

  function getCurBullet(groupIdx)
  {
    let bulGroup = this.getBulletGroupByIndex(groupIdx)
    return bulGroup && bulGroup.getSelBullet()
  }

  function updateWeapon()
  {
    if (!isUnitHaveSecondaryWeapons(this.unit))
      return

    let itemObj = this.scene.findObject(this.weaponItemId)
    if (!checkObj(itemObj))
      return

    this.showItemParams.hasMenu <- this.canChangeWeaponry && this.hasWeaponsToChooseFrom()
    let curWeapon = this.getCurWeapon()
    itemObj.show(curWeapon)
    if (!curWeapon)
      return

    updateModItem(this.unit, curWeapon, itemObj, false, this, this.showItemParams)
    this.showItemParams.hasMenu = false
  }

  function updateBullets()
  {
    let groups = this.getBulletsGroups()
    foreach(gIdx, bulGroup in groups)
    {
      let itemObj = this.scene.findObject(this.getBulletsItemId(gIdx))
      if (!checkObj(itemObj))
        continue

      this.showItemParams.visualDisabled <- !bulGroup.active
      this.showItemParams.hasMenu <- this.canChangeWeaponry && bulGroup.bullets.values.len() > 1
      updateModItem(this.unit, bulGroup.getSelBullet(), itemObj, false, this, this.showItemParams)
    }
    this.showItemParams.visualDisabled <- false
    this.showItemParams.hasMenu <- false
  }

  function updateBulletCountSlider(bulGroup, groupIdx)
  {
    let itemObj = this.scene.findObject(this.getBulletsItemId(groupIdx))
    if (checkObj(itemObj))
      updateItemBulletsSlider(itemObj, this.bulletsManager, bulGroup)
  }

  //included to updateBullets but much faster than full bullets update
  function updateAllBulletCountSliders()
  {
    let groups = this.getBulletsGroups()
    foreach(gIdx, bulGroup in groups)
      this.updateBulletCountSlider(bulGroup, gIdx)
  }

  function updateAllItems()
  {
    this.updateWeapon()
    this.updateBullets()
  }

  function onEventUnitWeaponChanged(_p)
  {
    this.updateAllItems()
  }

  function onEventBulletsGroupsChanged(_p)
  {
    this.updateBullets()
  }

  function onEventBulletsCountChanged(_p)
  {
    this.updateAllBulletCountSliders()
  }

  function getSelectionItemParams()
  {
    let res = clone this.showItemParams
    delete res.selectBulletsByManager
    return res
  }

  function getBulletGroupByItemId(id)
  {
    let idxStr = ::g_string.cutPrefix(id, this.bulletsIdPrefix, -1)
    return this.getBulletGroupByIndex(::to_integer_safe(idxStr, -1))
  }

  function openChangeWeaponryMenu(obj)
  {
    if (!this.canChangeWeaponry || !checkObj(obj))
      return

    let id = obj.holderId
    if (id == this.weaponItemId)
    {
      if (this.hasWeaponsToChooseFrom())
        ::gui_start_choose_unit_weapon(this.unit, null, {
          itemParams = this.getSelectionItemParams()
          alignObj = obj
          isForcedAvailable = this.isForcedAvailable
          forceShowDefaultTorpedoes = this.forceShowDefaultTorpedoes
        })
      return
    }

    let group = this.getBulletGroupByItemId(id)
    if (!group)
      return

    if (group.active)
    {
      if (group.bullets.values.len() > 1)
        this.bulletsManager.openChooseBulletsWnd(group.groupIndex, this.getSelectionItemParams(), obj)
    } else
      ::showInfoMsgBox(loc("msg/secondaryWeaponrequired"))
  }

  function onModItemClick(obj)
  {
    this.openChangeWeaponryMenu(obj)
  }

  function onWeaponryActivate(obj)
  {
    let value = obj.getValue()
    if (0 <= value && value < obj.childrenCount())
      this.openChangeWeaponryMenu(obj.getChild(value).findObject("centralBlock"))
  }

  function onModChangeBulletsSlider(obj)
  {
    if (!checkObj(obj))
      return
    let groupIndex = ::to_integer_safe(obj?.groupIdx ?? "", -1)
    let bulGroup= this.getBulletGroupByIndex(groupIndex)
    if (!bulGroup)
      return

    if (!this.bulletsManager.changeBulletsCount(bulGroup, obj.getValue()))
      this.updateBulletCountSlider(bulGroup, groupIndex) //move back current slider when value not changed
  }

  function onChangeBullets(diff = 1) //gamepad shortcut - search selected
  {
    if (!this.bulletsManager.canChangeBulletsCount())
      return
    let listObj = this.scene.findObject("weaponry_list")
    if (!checkObj(listObj) || !listObj.isFocused())
      return
    let idx = listObj.getValue()
    if (idx < 0 || listObj.childrenCount() <= idx)
      return

    let itemObj = listObj.getChild(idx)
    let id = ::g_string.cutPrefix(itemObj.id, this.bulletsIdPrefix, -1)
    let groupIdx = ::to_integer_safe(id, -1)
    let group = this.getBulletGroupByIndex(groupIdx)
    if (!group)
      return

    let step = max(group.getGunMaxBullets() / 20, 1).tointeger()
    this.bulletsManager.changeBulletsCount(group, group.bulletsCount + diff * step)
  }

  function onBulletsDecrease() { this.onChangeBullets(-1) }
  function onBulletsIncrease() { this.onChangeBullets(1) }

  function onModChangeBullets(obj, diff = 1) //real button, can be called not for selected mod, but have holderId
  {
    let group = this.getBulletGroupByItemId(obj.holderId)
    if (group)
      this.bulletsManager.changeBulletsCount(group, group.bulletsCount + diff)
  }

  function onModDecreaseBullets(obj) { this.onModChangeBullets(obj, -1) }
  function onModIncreaseBullets(obj) { this.onModChangeBullets(obj, 1) }
}
