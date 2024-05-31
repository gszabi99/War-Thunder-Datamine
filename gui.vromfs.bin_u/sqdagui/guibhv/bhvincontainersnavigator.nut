from "%sqDagui/daguiNativeApi.nut" import *
let { posNavigator } = require("bhvPosNavigator.nut")

let InContainersNavigator = class(posNavigator){
  bhvId = "inContainersNavigator"

  function onAttach(obj) {
    if (obj?.value)
      this.setValue(obj, obj.value.tointeger())
    obj.timer_interval_msec = "100"
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    if (obj.getIntProp(this.activatePushedIdxPID, -1) >= 0)
      this.onActivateUnpushed(obj)
    return RETCODE_NOTHING
  }

  function getChildObjRecursively(obj, value, params) {
    if (!obj.isVisible())
      return null

    if (obj?.isNavInContainerBtn == "yes") {
      if (value == params.currentIndex)
        return obj
      params.currentIndex++
      return null
    }

    if (obj?.isContainer) {
      let childsCount = obj.childrenCount()
      if (value >= params.currentIndex && value < childsCount + params.currentIndex)
        return obj.getChild(value - params.currentIndex)
      params.currentIndex += childsCount
      return null
    }

    if (params.currentDeep > 0) {
      let childsCount = obj.childrenCount()
      params.currentDeep--
      for (local i = 0; i < childsCount; i++) {
        let cObj = obj.getChild(i)
        if (cObj?.needSkipNavigation == "yes")
          continue
        let findedChild = this.getChildObjRecursively(cObj, value, params)
        if (findedChild != null)
          return findedChild
      }
      params.currentDeep++
    }
    return null
  }

  function getChildObj(obj, value) {
    let params = {currentCollapsed = 0, currentDeep = (obj?.deep ?? 0).tointeger(), currentIndex = 0}
    return this.getChildObjRecursively(obj, value, params)
  }

  function eachSelectableRecursively(obj, handler, params) {
    if (!obj.isVisible())
      return false

    if (obj?.isNavInContainerBtn == "yes") {
      if (this.isSelectable(obj) && handler(obj, params.currentIndex))
        return true
      params.currentIndex++
      return false
    }

    local objIsCollapsed = obj?.isCollapsed == "yes"
    params.currentCollapsed += objIsCollapsed ? 1 : 0

    if (obj?.isContainer) {
      let childsCount = obj.childrenCount()
      if (params.currentCollapsed == 0) {
        for (local i = 0; i < childsCount; i++) {
          let cObj = obj.getChild(i)
          if (this.isSelectable(cObj) && handler(cObj, params.currentIndex + i))
            return true
        }
      }
      params.currentCollapsed -= objIsCollapsed ? 1 : 0
      params.currentIndex += childsCount
      return false
    }

    if (params.currentDeep > 0) {
      let childsCount = obj.childrenCount()
      params.currentDeep--
      for (local i = 0; i < childsCount; i++) {
        let cObj = obj.getChild(i)
        if (cObj?.needSkipNavigation == "yes")
          continue
        if (this.eachSelectableRecursively(cObj, handler, params))
          return true
      }
      params.currentDeep++
    }

    params.currentCollapsed -= objIsCollapsed ? 1 : 0
    return false
  }

  function eachSelectable(obj, handler) {
    let params = {currentCollapsed = 0, currentDeep = (obj?.deep ?? 0).tointeger(), currentIndex = 0}
    this.eachSelectableRecursively(obj, handler, params)
  }

  function getHoveredChild(obj) {
    local hoveredObj = null
    local hoveredIdx = null
    this.eachSelectable(obj, function(child, i) {
      if (!child.isHovered())
        return false
      hoveredObj = child
      hoveredIdx = i
      return false
    })
    return { hoveredObj, hoveredIdx }
  }

  onInsert = @(_obj, _child, _index) {}

}

replace_script_gui_behaviour("inContainersNavigator", InContainersNavigator)

return {InContainersNavigator}