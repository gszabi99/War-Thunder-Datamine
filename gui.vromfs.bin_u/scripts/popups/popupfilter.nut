local { getStringWidthPx } = require("scripts/viewUtils/daguiFonts.nut")

const ALL_ITEMS  = "all_items"
const MORE_ITEMS = "more"
local moreTxt = $" {::loc("ui/ellipsis")} +"

local popupFilter = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "gui/popup/popupFilter"

  stateList            = null
  stateItems           = null
  isFilterVisible      = false
  iconNestObj          = null
  maxWidth             = null

  //init params
  filterTypes          = null
  btnName              = null
  btnTitle             = null
  onChangeFn           = null
  isTop                = false

  function getSceneTplView() {
    local rowsCount = 0
    local maxTextWidth = 0
    btnTitle = btnTitle ?? ::loc("stats_filter_show")
    maxWidth = (scene.getParent().getSize()[0] ?? 0) - ::to_pixels("1@buttonWidth")
      - getStringWidthPx($"{moreTxt}  ", "fontMedium")

    foreach (fType in filterTypes) {
      rowsCount = ::max(rowsCount, fType.checkbox.len())
      foreach (cb in fType.checkbox)
        if (cb?.text)
          maxTextWidth = ::max(maxTextWidth, getStringWidthPx(cb.text, "fontMedium"))
    }

    local columns = filterTypes.map(function(fType, idx) {
      local { checkbox } = fType
      if (!checkbox.len())
        return null

      local typeName = checkbox[checkbox.len()-1].id.split("_")[0]
      local params = $"pos:t='0, 1@popupFilterRowHeight-h'; type:t='rightSideCb'; typeName:t={typeName}"
      return fType.__merge({
        typeName
        isLast = false
        checkbox = checkbox.map(function(cb) {
          local isMultiple = cb.id == ALL_ITEMS
          return cb.__merge({
            isMultiple
            typeName
            funcName = isMultiple ? "onSelectAllChange" : "onCheckBoxChange"
            specialParams = params
            textWidth = maxTextWidth
          })
        })
      })
    }).filter(@(inst) inst != null)
    columns[columns.len()-1].isLast = true

    stateItems = columns.reduce(@(res, inst)
      res.extend(inst.checkbox.filter(@(cb) !cb.isMultiple)), []).append({ id = MORE_ITEMS })

    stateList = {}
    foreach( inst in stateItems)
      if (inst.id != MORE_ITEMS)
        stateList[inst.id] <- inst

    return {
      rowsCount = rowsCount
      columns = columns
      btnName = btnName ?? "Y"
      btnTitle = btnTitle
      underPopupClick    = "onShowFilterBtnClick"
      underPopupDblClick = "onShowFilterBtnClick"
      items = stateItems
      isTop = isTop
    }
  }

  function initScreen() {
    iconNestObj = scene.findObject("icon_nest")
    updateStates()
  }

  function updateColumns(typeName) {
    local curList  = stateList.filter(@(inst) inst.typeName == typeName)
    local columnObj = scene.findObject($"{typeName}_column")
    if (!columnObj?.isValid())
      return

    for (local i = 0; i < columnObj.childrenCount(); i++) {
      local child = columnObj.getChild(i)
      if (child.id == ALL_ITEMS)
        child.setValue(curList.findvalue(@(v) !v.value) == null)
      else
        child.setValue(curList[child.id].value)
    }
  }

  function onSelectAllChange(obj) {
    if (!onChangeFn)
      return

    local value    = obj.getValue()
    local curList  = stateList.filter(@(inst) inst.typeName == obj.typeName)
    if (value == (curList.findvalue(@(v) !v.value) == null))
      return

    foreach (inst in curList)
      stateList[inst.id].value = value

    updateStates()
    updateColumns(obj.typeName)
    onChangeFn(obj.id, obj.typeName, value)
  }

  function updateStates() {
    local isWidthExceed = false
    local hiddenCount = 0
    local totalWidth = 0
    for (local i = 0; i < stateItems.len(); i++) {
      //Use stateItems instead of stateList to get right items order
      local id = stateItems[i].id
      if (id == MORE_ITEMS)
        continue
      local inst = stateList[id]
      local textWidth = !inst.value ? 0
        : inst?.image ? ::to_pixels("1@checkboxSize + 2@blockInterval")
        : getStringWidthPx($" {inst.text} |", "fontMedium")
      totalWidth += textWidth
      isWidthExceed = totalWidth > maxWidth
      ::showBtn(id, isWidthExceed && inst.value ? false : inst.value, iconNestObj)
      hiddenCount = isWidthExceed && inst.value ? ++hiddenCount : hiddenCount
    }
    local moreObj = ::showBtn(MORE_ITEMS, isWidthExceed, iconNestObj)
    moreObj.setValue($"{moreTxt}{hiddenCount}")

  }
  function  onCheckBoxChange(obj) {
    if (!onChangeFn)
      return

    local value    = obj.getValue()
    local curInst = stateList[obj.id]
    if (value == curInst.value)
      return


    curInst.value = value
    updateStates()
    updateColumns(obj.typeName)
    onChangeFn(obj.id, obj.typeName, value)
  }

  function onShowFilterBtnClick(obj) {
    isFilterVisible = !isFilterVisible
    showSceneBtn("filter_popup", isFilterVisible)
  }
}

::gui_handlers.popupFilter <- popupFilter

return {
  openPopupFilter = @(params = {}) ::handlersManager.loadHandler(popupFilter, params)
}
