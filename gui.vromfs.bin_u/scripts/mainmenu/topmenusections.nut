from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { getCachedType, enumsAddTypes } = require("%sqStdLibs/helpers/enums.nut")

let topMenuSectionsTemplate = {
  name = "unknown"
  visualStyle = "noFrame"
  onClick = "onDropDownToggle"
  hoverMenuPos = "0"
  getText = function(_totalSections = 0) { return null }
  getImage = function(_totalSections = 0) { return null }
  getWinkImage = function() { return null }
  btnName = null
  buttons = null
  mergeIndex = -1
  haveTmDiscount = false
  forceHoverWidth = null
  isWide = false

  getTopMenuButtonDivId = @() $"topmenu_{this.name}"
  getTopMenuDiscountId = @() $"{this.getTopMenuButtonDivId()}_discount"
}

let isSeparateTab = @(section, totalSections) section ? section.mergeIndex < totalSections : true

function proceedButtonsArray(itemsArray, maxSectionsCount, sectionsStructure) {
  let result = []
  foreach (_idx, column in itemsArray) {
    result.append([])
    foreach (item in column) {
      if (u.isTable(item)) {
        result[result.len() - 1].append(item)
        continue
      }

      let newSection = sectionsStructure.getSectionByName(item)
      if (isSeparateTab(newSection, maxSectionsCount))
        continue

      let newSectionResult = proceedButtonsArray(newSection.buttons, maxSectionsCount, sectionsStructure)
      foreach (columnEx in newSectionResult)
        if (columnEx)
          result[result.len() - 1].extend(columnEx)
    }
  }
  return result
}

function clearEmptyColumns(itemsArray) {
  for (local i = itemsArray.len() - 1; i >= 0; i--) {
    if (u.isEmpty(itemsArray[i]))
      itemsArray.remove(i)
    else if (u.isArray(itemsArray[i]))
      clearEmptyColumns(itemsArray[i])
  }
}

function getTopMenuSectionsOrder(sectionsStructure, maxSectionsCount) {
  let sections = []
  foreach (_idx, section in sectionsStructure.types) {
    if (!isSeparateTab(section, maxSectionsCount))
      continue

    let result = clone section
    result.buttons = proceedButtonsArray(section.buttons, maxSectionsCount, sectionsStructure)
    sections.append(result)
  }

  foreach (section in sections)
    clearEmptyColumns(section.buttons)

  return sections
}

let getTopMenuSectionByName = @(name) getCachedType("name", name, this.cache.byName, this, this.template)

let topMenuLeftSideSections = {
  types = []
  cache = {
    byName = {}
  }

  template = topMenuSectionsTemplate
  getSectionByName = getTopMenuSectionByName
}





let addTopMenuLeftSideSections = @(sections) enumsAddTypes(topMenuLeftSideSections, sections)

let topMenuRightSideSections = {
  types = []
  cache = {
    byName = {}
  }

  template = topMenuSectionsTemplate
  getSectionByName = getTopMenuSectionByName
}

let addTopMenuRightSideSections = @(sections) enumsAddTypes(topMenuRightSideSections, sections)

return {
  topMenuSectionsTemplate
  getTopMenuSectionByName

  getTopMenuSectionsOrder

  addTopMenuLeftSideSections
  topMenuLeftSideSections

  addTopMenuRightSideSections
  topMenuRightSideSections
}
