activeText {
  id:t='txt_squad_title'
  text:t='#squad/title'
  pos:t='0, 50%(ph-h)'; position:t='relative'
  margin-right:t='@buttonTextPadding'
  inactive:t='yes'
  smallFont:t='yes'
}

Button_text {
  id:t='btn_squad_ready'
  pos:t='0, 50%(ph-h)'; position:t='relative'
  smallFont:t='yes'
  hideText:t='yes'
  display:t='hide'
  text:t='<<readyBtnHiddenText>>' //do not change this text for the fixed width of button on the all langs
  on_click:t='onSquadReady'

  btnText {
    id:t='text'
    left:t='50%pw-50%w'
    text:t='#mainmenu/btnReady'
  }
}

Button_text {
  id:t='btn_squadPlus'
  class:t='image'
  tooltip:t='#contacts/invite'
  on_click:t='onSquadPlus'

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
    background-image:t='#ui/gameuiskin#btn_inc.svg'
    tooltip:t='#contacts/invite'
  }
}

Button_text {
  id:t='btn_world_war'
  class:t='image'
  tooltip:t=''
  on_click:t='onWorldWar'
  <<^isWorldWarShow>>
  display:t='hide'
  enable:t='no'
  <</isWorldWarShow>>

  btnText {
    style:t='font:@fontBigBold'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h'
    position:t='absolute'
    text:t='#icon/worldWar'
  }
}

animated_wait_icon {
  id:t='wait_icon'
  pos:t='0, 50%(ph-h)'
  position:t="relative"
  class:t='byParent'
  background-rotation:t = '0'
}

<<#members>>
Button_text {
  id:t='member_<<id>>'
  display:t='hide'
  css-hier-invalidate:t='yes'
  class:t='squadWidgetMember'
  uid:t=''
  isMe:t='no'
  isInvite:t='no'
  status:t='offline'
  title:t='$tooltipObj'
  on_click:t='onSquadMemberMenu'
  on_r_click:t='onSquadMemberMenu'

  squadMemberNick {
    id:t='speaking_member_nick_<<id>>'
    pos:t='50%(pw-w), -h-1@blockInterval'; position:t='absolute'

    activeText {
      id:t='speaking_member_nick_text_<<id>>'
      margin:t='1@blockInterval'
      tinyFont:t='yes'
    }
  }

  mainPlayerHighlight {
    position:t='absolute'
    pos:t='0, 0'
    size:t='pw, ph'
  }

  tdiv {
    height:t='1@cIco'
    width:t='pw'
    pos:t='0, 0.5(ph-h)'; position:t='relative'
    css-hier-invalidate:t='yes'

    memberIcon {
      id:t='member_icon_<<id>>'
      pos:t='0, 3@sf/@pf'; position:t='relative'
      border:t='yes'
      border-color:t='@black'
    }

    tdiv {
      id:t='member_state_block_<<id>>'
      height:t='ph'
      margin-left:t='2@dp'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      tdiv {
        css-hier-invalidate:t='yes'

        tdiv {
          position:t='relative'
          css-hier-invalidate:t='yes'
          <<^showCrossplayIcon>>
            showCrossplayIcon:t='no'
          <</showCrossplayIcon>>

          squadMemberCrossPlayStatus {
            id:t='member_crossplay_active_<<id>>'
            isEnabledCrossPlay:t='no'
          }

          squadMemberStatus {
            id:t='member_ready_<<id>>'
          }
        }

        squadMemberVoipStatus {
          id:t='member_voip_<<id>>'
          isVoipActive:t='no'
        }
      }

      img {
        id:t='member_country_<<id>>'
        size:t='@sIco, @sIco';
        background-svg-size:t='@sIco, @sIco';
        background-image:t=''
      }
    }
  }

  animated_wait_icon {
    id:t='member_waiting_<<id>>'
    display:t='hide'
    background-rotation:t='0'
  }

  tooltipObj {
    id:t='member_tooltip_<<id>>'
    uid:t=''
    on_tooltip_open:t='onContactTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
}
<</members>>

Button_text {
  id:t='btn_squadInvites'
  class:t='image'
  tooltip:t='#squad/invited_players'
  on_click:t='onSquadInvitesClick'
  type:t='squadInvites'

  tdiv {
    id:t='invite_widget'
    pos:t='50%(pw-w), 0'; position:t='absolute'
  }

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
  }
  img {
    id:t='iconGlow'
    background-image:t='#ui/gameuiskin#mail_new_glow'
    style:t='background-color:@textureGlowColor; size:110%ph, 110%ph'
    _transp-timer:t='0'
    display:t='hide'
  }

}

Button_text {
  id:t='btn_squadLeave'
  class:t='image'
  tooltip:t=''
  on_click:t='onSquadLeave'
  type:t='squadLeave'

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
    background-image:t='#ui/gameuiskin#btn_close.svg'
  }
}
