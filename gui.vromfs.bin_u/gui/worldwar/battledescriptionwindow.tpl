root {
  blur {}
  blur_foreground {}

  frame {
    class:t='wndNav'
    largeNavBarHeight:t='yes'
    type:t='dark'

    size:t='1@slotbarWidthFullExt, 1@maxWindowHeightWithSlotbar +1@slotbar_top_shade +1@slotbarTop'
    pos:t='50%pw-50%w, 1@minYposWindow'
    position:t='absolute'

    frame_header {
      activeText {
        id:t='battle_description_frame_text'
        text:t='#userlog/page/battle'
        caption:t='yes'
      }

      Button_close {}
      <<#hasRefreshButton>>
      top_right_holder {
        id:t='header_buttons'
        Button_text {
          id:t = 'btn_refresh'
          on_click:t = 'onRefresh'
          tooltip:t = '#mainmenu/btnRefresh'
          class:t='image'
          imgSize:t='big'
          visualStyle:t='noFrame'
          img{ background-image:t='#ui/gameuiskin#refresh.svg' }
        }
      }
      <</hasRefreshButton>>
    }

    tdiv {
      size:t='pw, ph'

      chapterListPlace {
        id:t='chapter_place'
        height:t='ph'
        flow:t='vertical'
        increaseWidthForWide:t='yes'

        textareaNoTab {
          id:t='no_active_battles_text'
          width:t='pw'
          margin-top:t='0.01@scrn_tgt'
          text-align:t='center'
          text:t='#worldwar/operation/noActiveBattles'
        }

        listbox {
          id:t='items_list'
          size:t='pw, fh'
          flow:t = 'vertical'
          on_select:t='onItemSelect'
        }

        tdiv {
          id:t='queue_info'
          size:t='pw, ph'
          flow:t='vertical'
        }

        tdiv {
          id:t='squad_info'
          size:t='pw, fh'
          flow:t = 'vertical'
        }
      }

      blockSeparator { margin:t='1, 0' }

      tdiv {
        size:t='fw, ph'
        flow:t='vertical'

        tdiv {
          id:t='item_desc'
          size:t='pw, fh'
          flow:t='vertical'
        }

        tdiv {
          left:t='pw-w'
          position:t='relative'

          activeText {
            id:t='cant_join_reason_txt'
            top:t='50%ph-50%h'
            position:t='relative'
            padding-right:t='1@blockInterval'
            text:t=''
          }
          cardImg {
            id:t='warning_icon'
            padding-right:t='1@blockInterval'
            display:t='hide'
            background-image:t='#ui/gameuiskin#btn_help.svg'
            tooltip:t=''
          }
        }

        tdiv {
          id:t='operation_loading_wait_anim'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'
          display:t='hide'

          textareaNoTab {
            text:t='#loading'
            margin-right:t='1@framePadding'
            top:t='50%ph-50%h'
            position:t='relative'
          }

          animated_wait_icon
          {
            background-rotation:t='0'
            display:t='show'
          }
        }
      }
    }

    navBar {
      navLeft{
        Button_text {
          id:t='invite_squads_button'
          text:t='#worldwar/inviteSquads'
          on_click:t='onOpenSquadsListModal'
          btnName:t='Y'
          display:t='hide'
          enable:t='no'
          ButtonImg {}
        }

        Button_text {
          id:t='btn_battles_filters'
          text:t='<<?worldwar/battleFilters>>'
          _on_click:t='onOpenBattlesFilters'
          btnName:t='Y'
          display:t='hide'
          enable:t='no'
          ButtonImg {}
        }
      }

      navRight {
        Button_text {
          id:t='btn_slotbar_help'
          text:t='#topmenu/help'
          _on_click:t='onShowSlotbarHelp'
          btnName:t='L3'
          display:t='hide'
          enable:t='no'
          ButtonImg {}

          hasUnseenIcon:t='no'
          newIconWidget {
            id:t='btn_slotbar_help_unseen_icon'
            display:t='hide'
            newIconWidgetImg {
              background-image:t='#ui/gameuiskin#new_icon.svg'
            }
          }
        }
        Button_text {
          id:t='btn_auto_preset'
          text:t='#worldwar/btnAutoPreset'
          _on_click:t='onRunAutoPreset'
          btnName:t='R3'
          display:t='hide'
          enable:t='no'
          ButtonImg {}
          warningIcon {
            id:t='auto_preset_warning_icon'
            type:t='warning'
            tooltip:t='#generatePreset/warning/can_create_best_preset/tooltip'
            display:t='hide'
          }
        }
        Button_text {
          id:t='btn_join_battle'
          class:t='battle'
          navButtonFont:t='yes'
          _on_click:t='onJoinBattle'
          css-hier-invalidate:t='yes'
          isCancel:t='no'
          btnName:t='X'
          inactive:t='no'
          display:t='hide'
          enable:t='no'

          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          ButtonImg {}
          textarea {
            id:t='btn_join_battle_text'
            class:t='buttonText'
            text:t='#mainmenu/toBattle'
          }
        }
        Button_text {
          id:t='btn_leave_battle'
          class:t='battle'
          navButtonFont:t='yes'
          text:t='#mainmenu/btnCancel'
          _on_click:t='onLeaveBattle'
          css-hier-invalidate:t='yes'
          isCancel:t='yes'
          btnName:t='B'
          display:t='hide'
          enable:t='no'

          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          ButtonImg{}
          btnText {
            id:t='btn_leave_event_text'
            text:t='#mainmenu/btnCancel'
          }
        }
      }
      slotbarNest {
        pos:t='50%sw-50%w, sh-h-1@slotbarOffset'
        position:t='root'

        slotbarDiv {
          id:t='nav-slotbar'
        }
      }
    }
  }
  timer {
    id:t="update_timer"
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='1000'
  }
}

DummyButton {
  behaviour:t='accesskey'
  accessKey:t='F1'
  on_click:t='onHelp'
}