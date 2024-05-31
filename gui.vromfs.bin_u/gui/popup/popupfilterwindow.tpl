rootUnderPopupMenu {
  on_click:t='<<underPopupClick>>'
  on_r_click:t='<<underPopupDblClick>>'
}

include "%gui/popup/popupFilterButton.tpl"

popup_menu {
  id:t='filter_popup'
  position:t='relative'
  flow:t='horizontal'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  order-popup:t='yes'
  <<#columns>>
  tdiv {
    id:t='<<typeName>>_column'
    typeName:t='<<typeName>>'
    pos:t='1@dp, 0'
    position:t='relative'
    padding:t='1@blockInterval, 0'
    flow:t='vertical'
    include "%gui/commonParts/checkbox.tpl"
    Button_text {
      id:t='reset_btn'
      top:t='1@blockInterval'
      position:t='relative'
      typeName:t='<<typeName>>'
      width:t='<<textWidth>>+1@checkboxSize<<#hasIcon>>+1@cIco<</hasIcon>>'
      visualStyle:t='borderNoBgr'
      on_click:t='onResetFilters'
      text:t='#mainmenu/btnReset'
      <<^isResetShow>>
      display:t='hide'
      <</isResetShow>>
    }

    <<^isLast>>
    tdiv {
      id:t='separator'
      size:t='1@dp, ph'
      left:t='pw'
      position:t='absolute'
      background-color:t='@separatorBlockColor'
    }
    <</isLast>>
  }
  <</columns>>

}