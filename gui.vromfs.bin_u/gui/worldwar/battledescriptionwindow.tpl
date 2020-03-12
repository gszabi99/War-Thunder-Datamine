root {
  background-color:t='@shadeBackgroundColor'

  frame {
    class:t='wndNav'
    largeNavBarHeight:t='yes'
    type:t='dark'

    size:t='1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar'
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
        behaviour:t='wrapNavigator'
        navigatorShortcuts:t='yes'
        childsActivate:t='yes'
        on_wrap_up:t='onWrapUp'
        on_wrap_down:t='onWrapDown'
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
          <<#hasGotoGlobalBattlesBtn>>
          height:t='fh'
          <</hasGotoGlobalBattlesBtn>>
          margin-top:t='0.01@scrn_tgt'
          text-align:t='center'
          text:t='#worldwar/operation/noActiveBattles'
        }

        tdiv {
          id:t='active_country_info'
          width:t='pw'
          margin-right:t='1@framePadding'
          margin-top:t='0.05@scrn_tgt'
          flow:t='vertical'
        }

        listbox {
          id:t='items_list'
          size:t='pw, fh'
          flow:t = 'vertical'
          focus:t='yes'
          on_select:t='onItemSelect'
          on_wrap_up:t='onWrapUp'
          on_wrap_down:t='onWrapDown'
        }

        <<#hasGotoGlobalBattlesBtn>>
        tdiv {
          width:t='pw'
          flow:t='vertical'

          textareaNoTab {
            id:t='no_available_battles_alert_text'
            width:t='pw'
            padding:t='1@framePadding'
            text-align:t='center'
            smallFont:t='yes'
            bgcolor:t='@surrenderPanelColorBG'
            text:t='#worldwar/no_available_battle_in_operation'
          }

          Button_text {
            id:t='goto_global_battles_btn'
            width:t='pw'
            margin-top:t='1@blockInterval'
            text:t='#worldWar/btn_all_battles_full_text'
            on_click:t='onOpenGlobalBattlesModal'
            visualStyle:t='secondary'
            btnName:t='LT'
            ButtonImg {}
          }
        }
        <</hasGotoGlobalBattlesBtn>>

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
          id:t='cluster_select_button'
          width:t='1@bigButtonWidth'
          on_click:t='onOpenClusterSelect'
          btnName:t='X'
          refuseOpenHoverMenu:t='no'
          display:t='hide'
          enable:t='no'

          textarea {
            id:t='cluster_select_button_text'
            text:t='#options/cluster'
            height:t='ph'
            width:t='pw'
            pare-text:t='yes'
            input-transparent:t='yes'
            class:t='buttonText'
          }
          ButtonImg {}
        }

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
              background-image:t='#ui/gameuiskin#new_icon'
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
          btnName:t='A'
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
    }
  }
  timer {
    id:t="update_timer"
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='1000'
  }
}
