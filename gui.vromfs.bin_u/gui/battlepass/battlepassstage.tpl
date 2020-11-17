<<#battlePassStage>>
battlePassStage {
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

  tdiv {
    size:t='1@itemWidth, 1@itemHeight'
    pos:t='50%pw-50%w, 1@battlePassFlagSize + 1@blockInterval'
    position:t='absolute'

    include "gui/items/item"

    <<^items>>
    <<#challengeTooltipId>>
    img {
      position:t='absolute'
      size:t='pw, ph'
      background-image:t='https://static-ggc.gaijin.net/item_special_task.png' /*!!! FIX ME need replaced after 2.1.0.X by #ui/gameuiskin#item_challenge*/
      input-transparent:t='yes'

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<challengeTooltipId>>'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }
    }
    <</challengeTooltipId>>
    <</items>>

    tdiv {
      position:t='absolute'
      pos:t='0, ph - h'
      <<@warbondShopLevelImage>>
    }
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
        skip-navigation:t='yes'
        buttonWink{}
        buttonGlance{}
        ButtonImg {
          btnName:t='A'
          showOnSelect:t='hover'
        }
      }
    }
    statusImg { display:t='hide' }
  }
}
<</battlePassStage>>
