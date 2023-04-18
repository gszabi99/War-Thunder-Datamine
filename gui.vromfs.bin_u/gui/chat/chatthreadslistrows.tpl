<<#threads>>
expandable {
  id:t='room_<<roomId>>'
  roomId:t='<<roomId>>'
  class:t='simple'
  input-transparent:t='yes'
  <<#isJoined>>
  active:t='yes'
  <</isJoined>>
  <<#noSelect>>
  fullSize:t='yes'
  <</noSelect>>
  <<#addTimer>>
  behavior:t = 'Timer'
  timer_handler_func:t = 'onThreadTimer'
  timer_interval_msec:t='1000'
  <</addTimer>>

  <<#isConcealed>>
    display:t='hide'
    enable:t='no'
  <</isConcealed>>

  <<^onlyInfo>>
  on_click:t = 'onJoinThread'
  clickable:t='yes'
  <</onlyInfo>>
  highlightedRowLine {}
  selImg {
    id:t='thread_row_sel_img'
    flow:t='vertical'

    tdiv {
      width:t='pw'

      tdiv {
        width:t='fw'
        <<#needShowLang>>
        tdiv {
          id:t='thread_lang'
          <<#getLangsList>>
          cardImg {
            margin-right:t='1@buttonMargin'
            background-image:t='<<icon>>'
          }
          <</getLangsList>>
        }
        <</needShowLang>>

        textareaNoTab {
          id:t='ownerName_<<roomId>>'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          roomId:t='<<roomId>>'
          overlayTextColor:t='minor'
          smallFont:t='yes'
          text:t='<<getOwnerText>>'
          focusBtnName:t='A'

          behaviour:t='button'
          on_r_click:t='onUserInfo'
          on_click:t='onUserInfo'
        }

        <<#canEdit>>
        Button_text {
          roomId:t='<<roomId>>'
          pos:t='0, 50%ph-50%h'
          width:t='fw'
          max-width:t='1@bigButtonWidth'
          margin-right:t='1@buttonMargin'
          margin-left:t='1@buttonMargin'
          overflow:t='hidden'
          position:t='relative'
          showConsoleImage:t='no'
          scaleble:t='yes'
          class:t='smallButton'

          text:t = '#chat/editThread'
          on_click:t = 'onEditThread'
        }
        <</canEdit>>
      }
      textareaNoTab {
        id:t='thread_members'
        pos:t='pw-w, 0'
        smallFont:t='yes'
        overlayTextColor:t='minor'
        text:t='<<getMembersAmountText>>'
      }
    }

    tdiv {
      width:t='pw'

      textareaNoTab {
        id:t='thread_title'
        width:t='fw'
        max-height:t='0.09@sf'
        pos:t='0, ph-h'
        position:t='relative'
        padding-right:t='4*@sf/@pf_outdated'
        smallFont:t='yes'
        overlayTextColor:t='active'
        overflow-y:t='auto'
        scrollbarShortcutsOnSelect:t="focus"
        text:t='<<getTitle>>'
      }

      <<^onlyInfo>>
      <<#isGamepadMode>>
      tdiv {
        height:t='1@buttonHeight'
        pos:t='0, ph-h'
        position:t='relative'

        Button_text {
          id:t='action_btn'
          pos:t='0, ph-h'
          position:t='relative'
          noMargin:t='yes'
          roomId:t='<<roomId>>'

          text:t = '#mainmenu/btnAirAction'
          on_click:t = 'onThreadsActivate'
          btnName:t=''
          ButtonImg {
            btnName:t='A'
            showOnSelect:t='hover'
          }
        }
      }
      <</isGamepadMode>>
      <</onlyInfo>>
    }
  }
}
<</threads>>
