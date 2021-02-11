blur {}
blur_foreground {}

expandable {
  id:t='<<performActionId>>'
  <<#action>> on_click:t='<<action>>' <</action>>

  fullSize:t='yes'
  headerBg {
    battlePassStamp{
      pos:t='1@blockInterval, 0.5@blockInterval'
      position:t='absolute'
    }

    tdiv {
      behaviour:t='bhvUpdateByWatched'
      height:t='ph'
      left:t='1@arrowButtonWidth-w'
      position:t='relative'
      value:t='<<seasonLvlValue>>'

      textareaNoTab {
        top:t='0.5ph-0.5h'
        position:t='relative'
        text:t='#mainmenu/rank'
        margin-right:t='1@blockInterval'
        normalBoldFont:t='yes'
      }

      battlePassFlag {
        top:t='0.5ph-0.5h'
        position:t='relative'
        flagSize:t='small'

        textareaNoTab {
          id:t='flag_text'
          text:t=''
        }
      }
    }
  }

  <<#rewards>>
  tdiv {
    behaviour:t='bhvUpdateByWatched'
    value:t='<<hasRewardValue>>'
    padding-left:t='1@blockInterval'
    display:t='hide'

    img {
      size:t='@cIco, @cIco'
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='<<rewardIcon>>'
    }
    textareaNoTab {
      text:t='<<rewardText>>'
    }
  }
  <</rewards>>
}
