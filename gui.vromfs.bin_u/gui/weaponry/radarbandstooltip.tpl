weaponTooltipBlock {
  id:t='main_block'
  min-width:t='360@sf/@pf'
  flow:t='vertical'
  css-hier-invalidate:t='yes'
  weaponPresetTooltipHeader {
    width:t='pw'
    background-color:t='@buttonColor'

    activeText {
      width:t='pw'
      padding:t='1@bulletTooltipPadding, 1/2@bulletTooltipPadding'
      normalFont:t='yes'
      text:t='<<name>>'
    }
  }
  <<#hasDifferentTagetTypes>>
  HorizontalListBox {
    id:t='targets_types'
    height:t='1@frameHeaderHeight'
    class:t='header'
    normalFont:t='yes'
    value:t='0'
    on_select:t='onTargetTypeChange'

    include "%gui/frameHeaderTabs.tpl"
  }
  <</hasDifferentTagetTypes>>
  tdiv {
    id:t='units_list'
    width:t='pw'
    max-height:t='0.8@rh'
    flow:t='vertical'
    overflow-y:t='auto'
    padding:t='1@blockInterval'

    include "%gui/unit/textListOfUnits.tpl"
  }
}
