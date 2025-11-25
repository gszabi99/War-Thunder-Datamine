tdiv {
  id:t='filter_popup_nest'

  rootUnderPopupMenu {
    _on_click:t='<<underPopupClick>>'
    _on_r_click:t='<<underPopupDblClick>>'
    order-popup:t='yes'
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
      <<^isButtonsOnTop>>
      include "%gui/commonParts/checkbox.tpl"
      tdiv {
        id:t='separator'
        size:t='pw, 1@blockInterval'
      }
      <</isButtonsOnTop>>
      Button_text {
        id:t='reset_btn'
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
      Button_text {
        id:t='select_all_btn'
        position:t='relative'
        typeName:t='<<typeName>>'
        width:t='<<textWidth>>+1@checkboxSize<<#hasIcon>>+1@cIco<</hasIcon>>'
        visualStyle:t='borderNoBgr'
        on_click:t='onSelectAllFilters'
        text:t='#ui/select_all'
        <<^isSelectAllShow>>
        display:t='hide'
        <</isSelectAllShow>>
      }
      <<#isButtonsOnTop>>
      tdiv {
        id:t='separator'
        size:t='pw, 1@blockInterval'
      }
      include "%gui/commonParts/checkbox.tpl"
      <</isButtonsOnTop>>
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
}