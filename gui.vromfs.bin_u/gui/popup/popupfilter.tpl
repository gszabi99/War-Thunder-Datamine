tdiv {
  flow:t='horizontal'
  Button_text {
    id:t='filter_button'
    class:t='image'
    noMargin:t='yes'
    width:t='<<btnWidth>>'
    visualStyle:t='<<visualStyle>>'
    on_click:t='onShowFilterBtnClick'
    btnName:t='<<btnName>>'
    ButtonImg{}
    img {
      background-image:t='#ui/gameuiskin#filter_icon.svg'
    }
    textarea {
      id:t='filter_button_text'
      pos:t='pw-w, 0.5ph-0.5h'
      padding-right:t='1@buttonImgPadding'
      position:t='absolute'
    }
  }
}

popup_menu {
  id:t='filter_popup'
  <<^isNearRight>>
  top:t='<<^isTop>>1@blockInterval<</isTop>><<#isTop>>-h-1@buttonHeight-1@blockInterval<</isTop>>'
  <<#isRight>>
  left:t='pw-w'
  <</isRight>>
  <</isNearRight>>
  <<#isNearRight>>
  pos:t='<<btnWidth>>+1@blockInterval, -h'
  <</isNearRight>>
  position:t='relative'
  display:t='hide'
  enable:t='no'
  flow:t='horizontal'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'
  order-popup:t='yes'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
  }
  dummy { // To avoid close menu on click outside of button but inside area
    size:t='pw, ph'
    position:t='absolute'
  }
  <<#columns>>
  tdiv {
    id:t='<<typeName>>_column'
    typeName:t='<<typeName>>'
    pos:t='1@dp, 0'
    position:t='relative'
    padding:t='1@blockInterval, 0'
    flow:t='vertical'
    include "%gui/commonParts/checkbox"
    Button_text {
      id:t='reset_btn'
      top:t='1@blockInterval'
      position:t='relative'
      typeName:t='<<typeName>>'
      width:t='<<textWidth>>+1@cIco+1@checkboxSize'
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
