<<#wwRewards>>
rewardItem {
  margin-right:t='1@blockInterval'
  status:t='<<status>>'

  tdiv {
    size:t='1@battlePassFlagSize, 1@battlePassFlagSize'
    pos:t='pw-w, 1@blockInterval'
    position:t='absolute'
    tooltip:t='<<iconTooltipText>>'
    <<#isTrophy>>
    dailyIcon {}
    <</isTrophy>>
    rewardFlag {
      textareaNoTab {
        id:t='flag_text'
        text:t='<<progressTxt>>'
      }
    }
  }

  tdiv {
    size:t='1@itemWidth, 1@itemHeight'
    pos:t='50%pw-50%w, 1@battlePassFlagSize + 1@blockInterval'
    position:t='absolute'
    tooltip:t='<<descTooltipText>>'

    layeredIconContainer{
      size:t='pw-4@itemPadding, ph-4@itemPadding'
      position:t='absolute'
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      decal_locked:t='no'
      achievement_locked:t='no'
     <<@rewardImage>>
    }
  }
  <<#isTrophy>>
  bottomBar {
    width:t='pw'
    textareaNoTab {
      min-width:t='pw-2@blockInterval'
      top:t='0.5ph-0.5h'
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
