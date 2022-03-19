optionsList {
  id:t='<<id>>'
  width:t='pw'
  pos:t='(pw-w)/2, <<topPos>>'
  position:t='<<position>>'
  class:t='optionsTable'
  baseRow:t='yes'
  behavior:t='PosOptionsNavigator'
  value:t='<<value>>'
  <<#onClick>>
  on_click:t='<<onClick>>'
  <</onClick>>

  <<#row>>
  include "gui/commonParts/tableRow"
  <</row>>
}