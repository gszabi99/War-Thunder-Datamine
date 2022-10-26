<<#battlePassStage>>
battlePassStage {
  <<#doubleWidthStageIcon>>
  doubleWidthStageIcon:t='yes'
  <</doubleWidthStageIcon>>
  stageStatus:t='<<stageStatus>>'
  prizeStatus:t='<<prizeStatus>>'
  margin:t='1@battlePassStageMargin, 0'
  holderId:t='<<holderId>>'
  stage:t='<<stage>>'
  on_click:t='onReceiveRewards'

  <<#isFree>>
  tdiv {
    size:t='pw, 1@battlePassFreeTextHeight'
    pos:t='0, -1@battlePassFreeTextMargin - h'
    position:t='absolute'
    background-color:t='@battlePassFreeBgColor'
    activeText {
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='relative'
      text:t='#shop/free'
    }
  }
  <</isFree>>
  border {}
  battlePassFlag {
    textareaNoTab {
      id:t='flag_text'
      text:t='<<stage>>'
    }
  }

  stageContent  {
    pos:t='50%pw-50%w, 1@battlePassFlagSize + 1@blockInterval'
    position:t='absolute'

    tdiv {
      left:t='50%pw-50%w'
      position:t='absolute'
      include "%gui/items/item.tpl"
    }

    <<#stageIcon>>
    img {
      size:t='pw - 2@itemPadding, ph - 2@itemPadding'
      pos:t='0.5pw-0.5w, 0.5ph - 0.5h'
      position:t='absolute'
      background-image:t='<<stageIcon>>'
      input-transparent:t='yes'
    }
    <</stageIcon>>
    <<#stageTooltipId>>
    title:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='<<stageTooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
    <</stageTooltipId>>

    tdiv {
      position:t='absolute'
      pos:t='0, ph - h'
      <<@warbondShopLevelImage>>
    }

    <<#previewButton>>
    hoverButton {
      position:t='absolute'
      pos:t='pw-w-2@itemPadding, ph-h'
      tooltip:t='<<tooltip>>'
      on_click:t='<<funcName>>'
      no_text:t='yes'
      icon { background-image:t='<<image>>' }
      <<@actionParamsMarkup>>
    }
    <</previewButton>>
  }

  bottomBar {
    buttonNest {
      width:t='pw'
      display:t='hide'
      Button_text {
        text:t = '#items/getRewardShort'
        visualStyle:t='purchase'
        noMargin:t='yes'
        parentWidth:t='yes'
        btnName:t=''
        on_click:t='onReceiveRewards'
        holderId:t='<<holderId>>'
        stage:t='<<stage>>'
        <<#skipButtonNavigation>>skip-navigation:t='yes'<</skipButtonNavigation>>
        buttonWink{}
        buttonGlance{}
        ButtonImg {
          btnName:t='A'
          showOnSelect:t='hover'
        }
      }
    }
    lockButtonNest {
      width:t='pw'
      display:t='hide'
      Button_text {
        noMargin:t='yes'
        parentWidth:t='yes'
        <<#isFree>>isFree:t='yes'<</isFree>>
        on_click:t='onStatusIconClick'
        class:t='image'
        showConsoleImage:t="no"
        img {
          position:t='absolute'
          pos:t='50%(pw-w), 50%(ph-h)'
          background-image:t='#ui/gameuiskin#stage_locked.svg'
        }
      }
    }
    statusImg { display:t='hide' }
  }
}
<</battlePassStage>>
