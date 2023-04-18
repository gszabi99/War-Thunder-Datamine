<<#teams>>
table
{
  id:t='<<tableId>>'
  width:t='pw/<<teamsAmount>> - 2 + (1 - <<teamsAmount>>) / <<teamsAmount>> * 1@itemsInterval'
  pos:t='1 <<^isFirst>>+@itemsInterval<</isFirst>>, 1'
  position:t='relative'
  baseRow:t='rows16'
  class:t='mpTable'

  behavior:t='PosNavigator'
  moveX:t='linear'
  moveY:t='linear'
  navigatorShortcuts:t='yes'
  selfFocusBorder:t='yes'

  css-hier-invalidate:t='yes'
  on_click:t = 'onTableClick'
  on_select:t = 'onTableSelect'
  on_dbl_click:t='onTableDblClick'
  on_r_click:t='onTableRClick'
  on_hover:t='onTableHover'
  on_unhover:t='onTableHover'

  <<@content>>
}
<</teams>>