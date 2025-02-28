tdiv {
  id:t='contact_tooltip'
  min-width:t='@contactTooltipMinWidth'
  min-height:t='229@sf/@pf'
  background-color:t='@frameDarkBackgroundColor'
  overflow:t='hidden'

  img {
    size:t='1184@sf/@pf, 160@sf/@pf'
    position:t='absolute'
    left:t='pw/2-w/2'
    background-repeat:t='aspect-ratio'
    background-image:t='!ui/images/profile_headers/<<headerBackground>>'
  }

  contactAvatar {
    size:t='@contactTooltipAvatarFullSize, @contactTooltipAvatarFullSize'
    position:t='relative'
    pos:t='1@contactTooltipAvatarMargin, 1@contactTooltipAvatarMargin'

    img {
      position:t='relative'
      pos:t='pw/2-w/2, ph/2-h/2'
      size:t='1@contactTooltipAvatarImgSize, 1@contactTooltipAvatarImgSize'
      background-svg-size:t='1@contactTooltipAvatarImgSize, 1@contactTooltipAvatarImgSize'
      background-image:t='<<icon>>'

      <<#hasAvatarFrame>>
      avatarFrame { background-image:t='!ui/images/avatar_frames/<<frame>>.avif' }
      <</hasAvatarFrame>>
    }
  }

  contentContainer {
    id:t='content-container'
    min-width:t='1@contactTooltipContentMinWidth'
    padding-bottom:t='8@sf/@pf'
    margin-left:t='1@contactTooltipAvatarMargin'
    flow:t='vertical'

    headerInfo {
      id:t='contact-header'
      height:t='160@sf/@pf'
      padding-right:t='16@sf/@pf'

      tdiv {
        margin-top:t='72@sf/@pf'
        flow:t='vertical'

        tdiv {
          <<#clanTag>>
          textareaNoTab {
            margin-right:t='1@blockInterval'
            text:t='<<clanTag>>'
            font-pixht:t='28@sf/@pf'
            normalFont:t='yes'
          }
          <</clanTag>>
          textareaNoTab {
            text:t='<<name>>'
            font-pixht:t='28@sf/@pf'
            normalBoldFont:t='yes'
          }
          textareaNoTab {
            margin-left:t='2@blockInterval'
            margin-top:t='2@dp'
            text:t='<<squadLeaderTxt>>'
            font-pixht:t='25@sf/@pf'
            normalFont:t='yes'
          }
        }

        textareaNoTab {
          position:t='relative'
          text:t='<<wtName>>'
        }

        textareaNoTab {
          position:t='relative'
          margin-top:t='4@sf/@pf'
          text:t='<<title>>'
          smallFont:t='yes'
        }
      }
    }

    statusesContainer {
      width:t='pw'
      margin-top:t='16@sf/@pf'
      margin-bottom:t='8@sf/@pf'

      onlineStatus {
        textareaNoTab {
          position:t='absolute'
          top:t='ph/2-h/2'
          text:t='#ui/bullet'
          bigBoldFont:t='yes'
          style:t='color=<<onlineStatusColor>>;'
        }
        textareaNoTab {
          position:t='relative'
          left:t='14@sf/@pf'
          text:t='<<onlineStatusText>>'
          smallFont:t='yes'
        }
      }

      <<#hasBattleOrSquadTxt>>
      battleOrSquadStatus {
        padding:t='1@blockInterval,0'
        width:t='fw'
        text {
          margin-x:t='1@blockInterval'
          text:t='#ui/bullet'
          smallFont:t='yes'
        }
        textareaNoTab {
          width:t='fw'
          text:t='<<battleOrSquadStatusTxt>>'
          smallFont:t='yes'
        }
      }
      <</hasBattleOrSquadTxt>>
    }

    <<#hasUnitList>>
    tdiv {
      width='pw'
      flow:t='vertical'

      <<#unitList>>
      tdiv {
        width:t='pw'
        unitContactRow {
          width:t='pw'
          padding-right:t='16@sf/@pf'
          <<#even>>
          even:t='yes'
          <</even>>
          <<#unit>>
          tdiv{
            width:t='2@sIco+2@blockInterval'
            img {
              position:t='relative'
              pos:t='(pw-w)/2,(ph-h)/2'
              size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
              background-svg-size:t='<<#isWideIco>>2<</isWideIco>>@sIco, @sIco'
              background-image:t='<<icon>>'
              background-repeat:t='aspect-ratio'
            }
          }
          activeText {
            valign:t='center'
            text:t='#<<unit>>_shop'
            smallFont:t='yes'
          }
          text {
            valign:t='center'
            right:t='0'
            text:t='<<rank>>'
            smallFont:t='yes'
          }
          <</unit>>
        }
      }
      <</unitList>>

      textareaNoTab {
        width:t='pw'
        margin-top:t='2@blockInterval'
        text:t='<<hint>>'
        smallFont:t='yes'
      }
    }
    <</hasUnitList>>
  }
}
