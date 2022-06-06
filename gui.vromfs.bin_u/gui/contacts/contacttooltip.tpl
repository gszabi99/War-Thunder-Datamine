tdiv {
  flow:t='vertical'

  tdiv {
    img {
      size:t='1@profileUnlockIconSize, 1@profileUnlockIconSize'
      background-image:t='#ui/images/avatars/<<icon>>'
    }
    tdiv {
      flow:t='vertical'
      margin-left:t='0.01@scrn_tgt'
      textareaNoTab {
        text:t='<<name>>'
        max-width:t='0.7@scrn_tgt'
      }
      tdiv {
        max-width:t='1@sIco + 1@scrn_tgt'
        contactStatusImg {
          id:t='statusImg'
          background-image:t='<<presenceIcon>>'
          background-color:t='<<presenceIconColor>>'
          pos:t='0, ph/2 - h/2'; position:t='relative'
        }
        textareaNoTab {
          id:t='contact-presenceText'
          text:t='<<presenceText>>'
          max-width:t='0.7@scrn_tgt'
          pos:t='0.01@scrn_tgt, ph/2 - h/2'; position:t='relative'
        }
      }
      textareaNoTab {
        text:t='<<?stats/missions_wins>><<?ui/colon>><<wins>>'
        max-width:t='0.7@scrn_tgt'
      }
      textareaNoTab {
        text:t='<<?mainmenu/rank>><<?ui/colon>><<rank>>'
        max-width:t='0.7@scrn_tgt'
      }
    }
  }

  tdiv {
    id:t='contact-aircrafts'
    flow:t='vertical'

    <<#unitList>>
    airRow {
    <<#header>>
      text {
        text:t='<<header>>';
        overlayTextColor:t='userlog'
      }

      text {
        text:t='#ui/colon';
        overlayTextColor:t='userlog'
      }
    <</header>>

    <<#unit>>
      cardImg {
        background-image:t='<<countryIcon>>'
      }
      text {
        text:t='(<<rank>>)'
      }
      activeText {
        text:t='#<<unit>>_shop'
      }
    <</unit>>

    <<#noUnit>>
      cardImg {
        background-image:t='<<countryIcon>>'
      }
      activeText {
        text:t='-'
      }
    <</noUnit>>
    }
    <</unitList>>
  }
}
