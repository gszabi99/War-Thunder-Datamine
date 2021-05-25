tdiv {
  flow:t='horizontal'
  height:t='1@popupFilterHeight'
  Button_text {
    id:t='filter_button'
    margin-left:t='0'
    text:t='<<btnTitle>>'
    on_click:t='onShowFilterBtnClick'
    btnName:t='Y'
    ButtonImg{}
  }
  tdiv {
    id:t='icon_nest'
    flow:t='horizontal'
    position:t='relative'
    pos:t='0, 0.5ph-0.5h'
    include "gui/commonParts/imgList"
  }
}

popup_menu {
  id:t='filter_popup'
  position:t='relative'
  height:t='<<rowsCount>>@popupFilterRowHeight+4@blockInterval'
  display:t='hide'
  enable:t='no'
  flow:t='horizontal'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
  }

  <<#columns>>
  tdiv {
    id:t='<<typeName>>_column'
    typeName:t='<<typeName>>'
    position:t='relative'
    flow:t='vertical'
    include "gui/commonParts/checkbox"
  }

  <<^isLast>>
  tdiv {
    size:t='1@dp, ph'
    position:t='relative'
    margin:t='1@blockInterval, 0'
    background-color:t='@separatorBlockColor'
  }
  <</isLast>>
  <</columns>>
}
