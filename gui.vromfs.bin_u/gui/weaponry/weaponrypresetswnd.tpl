tdiv {
  size:t='pw, ph'
  hangarControlTracking {}

  gamercard_div {
    include '%gui/gamercardTopPanel.blk'
    include '%gui/gamercardBottomPanel.blk'
  }

  tdiv {
    position:t='absolute'
    pos:t='0.5pw-0.5w, sh -1@bottomBarHeight -1@blockInterval -h'

    div {
      id:t='presets_nest'
      size:t='<<presetsWidth>> + 1@weaponsPresetDescriptionWidth + 1@scrollBarSize + 1@dp  + 2@framePadding, <<presetsHeightInTiers>>@tierIconSize'
      min-height:t='3@tierIconSize'
      max-height:t='1@maxWindowHeight'

      application-window:t='yes'
      window-size-border-mask:t='T'
      overflow:t='hidden'

      bgrStyle:t='fullScreenWnd'
      blur {}
      blur_foreground {}

      frame {
        size:t='pw, ph'
        class:t='wndNav'
        fullScreenSize:t='yes'
        isHeaderHidden:t='yes'
        input-transparent:t='yes'

        tdiv{
          size:t='pw, ph'
          flow:t='horizontal'
          css-hier-invalidate:t='yes'
          tdiv {
            size:t='fw, fh'
            overflow-y:t='auto'

            tdiv {
              id:t='presetNest'
              size:t='<<presetsWidth>>, ph'
              margin-right:t='1@scrollBarSize'
              flow:t='vertical'

              include "%gui/weaponry/weaponryPreset.tpl"
            }
          }
          blockSeparator{}
          tdiv{
            flow:t='vertical'
            size:t='1@weaponsPresetDescriptionWidth, ph'
            tdiv{
              flow:t='vertical'
              width:t='pw'
              max-height:t='ph'
              overflow-y:t='auto'
              padding-left:t='1@blockInterval'
              descriptionNest {
                id:t='desc'
                width:t='pw'
                padding:t='0, 1@blockInterval'
              }
              rowSeparator{}
              descriptionNest {
                id:t='tierDesc'
                width:t='pw'
                padding:t='0, 1@blockInterval'
              }
            }
          }
        }
        navBar {
          navLeft {
            width:t='pw'
            Button_text {
              id:t = 'btn_back'
              text:t = '#mainmenu/btnBack'
              btnName:t='B'
              _on_click:t = 'goBack'
              ButtonImg {}
            }
            popupFilter {
              pos:t='1@blockInterval, 0'
              position:t='relative'
              margin-top:t="1@buttonMargin"
              margin-bottom:t="1@buttonMargin"
            }
            Button_text {
              id:t='openPresetMenuBtn'
              text:t='#msgbox/presetActions'
              on_click:t='onPresetActionsMenuOpen'
              btnName:t='LB'
              display:t='hide'
              ButtonImg {}
            }
            Button_text {
              id:t='newPresetBtn'
              text:t='#chat/create'
              on_click:t='onPresetNew'
              btnName:t='RB'
              display:t='hide'
              ButtonImg {}
            }
            Button_text {
              id:t='btn_buyAll'
              btnName:t='L3'
              _on_click:t='onBuyAll'
              hideText:t='yes'
              display:t='hide'
              visualStyle:t='purchase'
              buttonWink{}
              buttonGlance{}
              textarea {
                id:t='btn_buyAll_text'
                class:t='buttonText'
              }
              ButtonImg {}
            }
            textareaNoTab {
              id:t='custom_weapons_available_txt'
              pos:t='1@buttonMargin, 0.5ph-0.5h'
              position:t='relative'
              text:t='#customSecondaryWeapons/available'
              overlayTextColor:t='active'
              display:t='hide'
            }
            textareaNoTab {
              id:t='custom_weapons_disabled_txt'
              pos:t='1@buttonMargin, 0.5ph-0.5h'
              position:t='relative'
              text:t='#customSecondaryWeapons/disabled'
              overlayTextColor:t='active'
              display:t='hide'
            }
          }
          navRight {
            Button_text{
              id:t='favoriteBtn'
              text:t=''
              on_click:t='onChangeFavorite'
              display:t='hide'
              btnName:t='LT'
              ButtonImg {}
            }
            Button_text{
              id:t='altActionBtn'
              text:t=''
              on_click:t='onAltModAction'
              display:t='hide'
              tooltip:t='<<altBtnTooltip>>'
              btnName:t='X'
              ButtonImg {}
            }
            Button_text{
              id:t='actionBtn'
              text:t=''
              on_click:t='onModActionBtn'
              display:t='hide'
              btnName:t='A'
              ButtonImg {}
            }
          }
        }
      }
    }
    tdiv {
      position:t='absolute'
      left:t='pw'
      flow:t='vertical'
      needButtonsMargin:t='yes'
      overflow:t='hidden'
      bgrStyle:t='fullScreenWnd'
      blur {}
      blur_foreground {}

      Button_text{
        id:t='increaseWndHeightBtn'
        class:t='image'
        showConsoleImage:t='no'
        on_click:t='onIncreaseWndHeightBtn'
        display:t='hide'
        img {
          background-image:t='#ui/gameuiskin#spinnerListBox_arrow_up.svg'
        }
      }

      Button_text{
        id:t='decreaseWndHeightBtn'
        class:t='image'
        showConsoleImage:t='no'
        on_click:t='onDecreaseWndHeight'
        display:t='hide'
        img {
          background-image:t='#ui/gameuiskin#spinnerListBox_arrow_up.svg'
          rotation:t='180'
        }
      }
    }
  }
  timer {
    id:t='timer_update'
    timer_handler_func:t='onUpdate'
    timer_interval_msec:t='1000'
  }
}
