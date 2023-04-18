tdiv {
  width:t='pw'
  margin:t='0, 1@framePadding'

  textareaNoTab {
    width:t='60%pw'
    padding-left:t='1@framePadding'
    overlayTextColor:t='active'
    text:t='#chat/squad'
  }
  textareaNoTab {
    width:t='40%pw'
    text-align:t='center'
    overlayTextColor:t='active'
    text:t='#squad/readiness'
  }
}

separatorLine{}

VerticalListBox {
  id:t='squad_list'
  size:t='pw, fh'
  flow:t = 'vertical'
  navigator:t='posNavigator'
  navigatorShortcuts:t='yes'
  on_r_click:t='onMemberRClick'

  <<#members>>
  memberView {
    width:t = 'pw'
    flow:t = 'vertical'
    css-hier-invalidate:t='all'

    tdiv {
      width:t = 'pw'

      tdiv {
        width:t='60%pw'
        top:t='50%ph-50%h'
        position:t='relative'

        textareaNoTab {
          id:t='member_name'
          top:t='50%ph-50%h'
          position:t='relative'
          padding-left:t='1@framePadding'
          text:t=''
        }
        tdiv {
          margin-left:t='1@dp'
          ButtonImg {
            class:t='independent'
            btnName:t='X'
            showOnSelect:t='yes'
          }
        }
      }


      tdiv {
        width:t='40%pw'
        flow:t='vertical'

        tdiv {
          width:t='pw'

          tdiv {
            width:t='33%pw'

            memberReadyIcon {
              id:t='is_ready_icon'
              tooltip:t='#squad/player_readiness'
              isReady:t='no'
            }
          }

          tdiv {
            width:t='33%pw'

            memberReadyIcon {
              id:t='has_vehicles_icon'
              tooltip:t='#squad/vehicles_presence'
              isReady:t='no'
            }
          }

          tdiv {
            width:t='33%pw'

            memberReadyIcon {
              id:t='is_crews_ready_icon'
              tooltip:t='#squad/crews_readiness'
              isReady:t='no'
            }
          }
        }
      }
    }

    tdiv {
      width:t='pw'
      margin:t='1@framePadding'

      textareaNoTab {
        id:t='cant_join_text'
        width:t='fw'
        top:t='50%ph-50%h'
        position:t='relative'
        padding-right:t='1@blockInterval'
        text-align:t='right'
        smallFont:t='yes'
        overlayTextColor:t='warning'
        hideEmptyText:t='yes'
        text:t=''
      }

      cardImg {
        id:t='alert_icon'
        display:t='hide'
        background-image:t='#ui/gameuiskin#btn_help.svg'
        tooltip:t=''
      }
    }

    separatorLine {}
  }
  <</members>>
}

DummyButton {
  id:t= 'member_menu_open'
  btnName:t = 'X'
  on_click:t = 'onMemberRClick'
  enable:t = 'no'
}
