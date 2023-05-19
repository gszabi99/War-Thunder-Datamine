//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
::g_top_menu_sections <- {
  template = {
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

    getTopMenuButtonDivId = function() { return "topmenu_" + this.name }
    getTopMenuDiscountId = function() { return this.getTopMenuButtonDivId() + "_discount" }
  }
}

::g_top_menu_sections.isSeparateTab <- function isSeparateTab(section, totalSections) {
  return section ? section.mergeIndex < totalSections : true
}

::g_top_menu_sections.getSectionsOrder <- function getSectionsOrder(sectionsStructure, maxSectionsCount) {
  let sections = []
  foreach (_idx, section in sectionsStructure.types) {
    if (!this.isSeparateTab(section, maxSectionsCount))
      continue

    let result = clone section
    result.buttons = this._proceedButtonsArray(section.buttons, maxSectionsCount, sectionsStructure)
    sections.append(result)
  }

  foreach (section in sections)
    this.clearEmptyColumns(section.buttons)

  return sections
}

::g_top_menu_sections._proceedButtonsArray <- function _proceedButtonsArray(itemsArray, maxSectionsCount, sectionsStructure) {
  let result = []
  foreach (_idx, column in itemsArray) {
    result.append([])
    foreach (item in column) {
      if (u.isTable(item)) {
        result[result.len() - 1].append(item)
        continue
      }

      let newSection = sectionsStructure.getSectionByName(item)
      if (this.isSeparateTab(newSection, maxSectionsCount))
        continue

      let newSectionResult = this._proceedButtonsArray(newSection.buttons, maxSectionsCount, sectionsStructure)
      foreach (columnEx in newSectionResult)
        if (columnEx)
          result[result.len() - 1].extend(columnEx)
    }
  }
  return result
}

::g_top_menu_sections.clearEmptyColumns <- function clearEmptyColumns(itemsArray) {
  for (local i = itemsArray.len() - 1; i >= 0; i--) {
    if (u.isEmpty(itemsArray[i]))
      itemsArray.remove(i)
    else if (u.isArray(itemsArray[i]))
      this.clearEmptyColumns(itemsArray[i])
  }
}

::g_top_menu_sections.getSectionByName <- function getSectionByName(name) {
  return enums.getCachedType("name", name, this.cache.byName, this, this.template)
}
