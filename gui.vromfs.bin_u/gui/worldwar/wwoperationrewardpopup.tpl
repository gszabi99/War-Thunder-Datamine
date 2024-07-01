root {
  blur {}
  blur_foreground {}

  tdiv {
    width:t='1@profileIconFullSize+6@lIco+8@wwPopupPadding'
    max-height:t='1@maxWindowHeight'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h'
    position:t='absolute'
    background-color:t='@frameHeaderBackgroundColor'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }
      Button_close { id:t = 'btn_back' }
    }

    tdiv {
      size:t='pw, ph'
      top:t='1@frameHeaderHeight'
      position:t='absolute'
      overflow:t='hidden'
      img {
        size:t='pw, 0.5w'
        position:t='absolute'
        background-color:t='@white'
        background-image:t='<<backgroundImg>>'
        background-svg-size:t='pw, 0.5w'
      }
      img {
        size:t='pw+2@dp, 1@wwPopupGradientHeight'
        position:t='absolute'
        background-image:t='#ui/gameuiskin#gradient_ww_window.svg'
        background-svg-size:t='pw, 1@wwPopupGradientHeight'
        background-position:t='2, 0'
        background-repeat:t='expand-svg'
      }
    }
    tdiv {
      width:t='pw'
      top:t='1@wwPopupContentTop'
      position:t='relative'
      flow:t='vertical'
      background-color:t='@frameHeaderBackgroundColor'

      //HEADER
      tdiv {
        left:t='0.5pw-0.5w'
        position:t='relative'
        flow:t='horizontal'
        textareaNoTab {
          id:t='win_tag'
          text:t='<<winClanTag>>'
          position:t='relative'
          padding:t='1@blockInterval, 0'
          bigBoldFont:t='yes'
        }
        img {
          size:t='1@dIco, 1@dIco'
          pos:t='0.5@wwPopupPadding, 0.5ph-0.5h'
          position:t='relative'
          background-image:t='#ui/gameuiskin#ww_operation_winner.svg'
          background-svg-size:t='1@dIco, 1@dIco'
          background-repeat:t='aspect-ratio'
        }
        textareaNoTab {
          text:t='<<vs>>'
          position:t='relative'
          padding:t='1@blockInterval, 0'
          bigBoldFont:t='yes'
        }
        img {
          size:t='1@mIco, 1@mIco'
          top:t='0.5ph-0.5h'
          position:t='relative'
          background-image:t='#ui/gameuiskin#ww_operation_loser.svg'
          background-svg-size:t='1@dIco, 1@dIco'
          background-repeat:t='aspect-ratio'
        }
        textareaNoTab {
          id:t='lose_tag'
          text:t='<<loseClanTag>>'
          left:t='0.5@wwPopupPadding'
          position:t='relative'
          padding:t='1@blockInterval, 0'
          bigBoldFont:t='yes'
        }
      }
      // USER STATS
      tdiv {
        left:t='0.5pw-0.5w'
        position:t='relative'
        padding:t='1@wwPopupPadding'
        padding-top:t='0.5@wwPopupPadding'
        flow:t='horizontal'
        memberIcon {
          size:t='1@profileIconFullSize, 1@profileIconFullSize'
          value:t='<<profileIco>>'
          isFull:t='yes'
          padding-right:t='1@wwPopupPadding'
        }
        <<#statsList>>
        <<#isDividingLine>>
        divider {
          position:t='relative'
          background-color:t='@commonTextColor'
          size:t='1@debrSepWidth, 2@lIco'
          top:t='ph/2 - h/2'
          padding:t='0.74@wwPopupPadding, 0, 0.74@wwPopupPadding, 0'
        }
        <</isDividingLine>>
        <<^isDividingLine>>
        tdiv {
          width:t=<<^hasManager>>'@lIco+1@wwPopupPadding'<</hasManager>><<#hasManager>>'0.74@lIco+0.74@wwPopupPadding'<</hasManager>>
          top:t='0.5ph-0.5h'
          position:t='relative'
          flow:t='vertical'
          tooltip:t='<<tooltip>>'
          img {
            size:t=<<^hasManager>>'@lIco, @lIco'<</hasManager>><<#hasManager>>'0.74@lIco, 0.74@lIco'<</hasManager>>
            left:t='0.5pw-0.5w'
            position:t='relative'
            background-image:t='<<statIcon>>'
            background-svg-size:t=<<^hasManager>>'@lIco, @lIco'<</hasManager>><<#hasManager>>'0.74@lIco, 0.74@lIco'<</hasManager>>
            background-repeat:t='aspect-ratio'
            style:t='background-color:@commonTextColor;'
          }
          textareaNoTab {
            pos:t='0.5pw-0.5w, 1@wwPopupPadding'
            position:t='relative'
            text:t='<<statVal>>'
            <<^hasManager>>
            bigBoldFont:t='yes'
            <</hasManager>>
            <<#hasManager>>
            normalBoldFont:t='yes'
            <</hasManager>>
          }
        }
        <</isDividingLine>>
        <</statsList>>
      }
      // REWARDS
      <<#rewardsList>>
      tdiv {
        width:t='pw'
        position:t='relative'
        padding:t='1@wwPopupPadding, 0, 1@wwPopupPadding, 1@wwPopupPadding'
        padding-bottom:t=<<#last>>'1@wwPopupPadding'<</last>><<^last>>'0.5@wwPopupPadding'<</last>>
        flow:t='horizontal'
        tdiv {
          size='pw, 1@mIco'
          position:t='absolute'
          tdiv {
            size:t='0.5pw, ph'
            background-image:t='#ui/gameuiskin#white_with_gradient_alpha'
            background-position:t='4, 4'
            rotation:t='180'
            background-repeat:t='expand'
            background-color:t='@frameDarkLineColor'
          }
          tdiv {
            size:t='0.5pw, ph'
            background-image:t='#ui/gameuiskin#white_with_gradient_alpha'
            background-position:t='4, 4'
            background-repeat:t='expand'
            background-color:t='@frameDarkLineColor'
          }
        }
        img {
          size:t='1@mIco, 1@mIco'
          top:t='0.5ph-0.5h'
          position:t='relative'
          background-image:t='<<icon>>'
          background-svg-size:t='1@mIco, 1@mIco'
          background-repeat:t='aspect-ratio'
        }
        textareaNoTab {
          pos:t='0.5@wwPopupPadding, 0.5ph-0.5h'
          position:t='relative'
          text:t='<<name>>'
          mediumFont:t='yes'
        }
        textareaNoTab {
          top:t='0.5ph-0.5h'
          right:t='0'
          position:t='relative'
          text:t='<<earnedText>>'
          mediumFont:t='yes'
        }
      }
      <</rewardsList>>
    }
  }
}
