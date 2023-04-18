<<#items>>
awardItemDiv {
  emptyBlock:t='<<emptyBlock>>'
  flow:t='vertical'
  interactive:t='yes'

  <<#skipNavigation>>
  skip-navigation:t='yes'
  <</skipNavigation>>

  awardItemHeader {
    size:t='pw, 1@awardItemHeaderHeight';
    <<#havePeriodReward>>
      <<^openedPicture>>
        havePeriodReward:t='yes'
      <</openedPicture>>
    <</havePeriodReward>>

    <<#current>>
      today:t='yes'
      arrowCurrent{}
    <</current>>

    tdiv {
      width:t='pw'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='relative'
      flow:t='vertical'
      textarea {
        id:t='award_day_text';
        pos:t='50%pw-50%w, 0';
        position:t='relative'
        removeParagraphIndent:t='yes'
        text:t='<<award_day_text>>';
        text-align:t='center'
      }
      textarea {
        id:t='award_day_text';
        pos:t='50%pw-50%w, -0.005@sf';
        position:t='relative'
        removeParagraphIndent:t='yes'
        text:t='<<week_day_text>>';
        text-align:t='center'
      }
    }
  }

  <<@item>>

  <<#periodicRewardImage>>
  periodicRewardImage {
    background-image:t='@!<<@periodicRewardImage>>'
    <<#openedPicture>>
      opened:t='yes'
    <</openedPicture>>
  }
  <</periodicRewardImage>>
}
<</items>>
