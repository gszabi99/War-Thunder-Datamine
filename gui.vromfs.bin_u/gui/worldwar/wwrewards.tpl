<<#wwRewards>>
rewardItem {
  padding-right:t='1@blockInterval'
  status:t='<<status>>'

  tdiv {
    size:t='1@battlePassFlagSize, 1@battlePassFlagSize'
    pos:t='pw-w, 1@blockInterval'
    position:t='absolute'
    tooltip:t='<<iconTooltipText>>'
    rewardFlag {
      textareaNoTab {
        id:t='flag_text'
        text:t='<<progressTxt>>'
      }
    }
    <<#isTrophy>>
    dailyIcon {}
    <</isTrophy>>
  }

  tdiv {
    size:t='1@itemWidth, 1@itemHeight'
    pos:t='50%pw-50%w, 1@battlePassFlagSize + 1@blockInterval'
    position:t='absolute'
    <<#tooltipId>>
    tooltipObj {
      id:t='tooltip_<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      display:t='hide'
    }
    title:t='$tooltipObj'
    <</tooltipId>>

    layeredIconContainer{
      size:t='pw-4@itemPadding, ph-4@itemPadding'
      position:t='absolute'
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
     <<@rewardImage>>
    }
  }
  <<#isTrophy>>
  bottomBar {
    width:t='pw'
    tooltip:t='<<descTooltipText>>'
    textareaNoTab {
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      position:t='relative'
      padding:t='1@blockInterval, 0'
      smallFont:t='yes'
      text:t='<<trophyDesc>>'
    }
  }
  <</isTrophy>>
  statusImg {}
}
<</wwRewards>>
