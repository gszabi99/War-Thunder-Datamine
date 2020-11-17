root {
  blur {}
  blur_foreground {}
  on_click:t='goBack'

  frame {
    id:t='wnd_frame'
    size:t='0.95@rw, 0.9@rh'
    pos:t='50%pw-50%w, 50%sh-50%h'
    position:t='absolute'
    class:t='wnd'

    frame_header {
      activeText {
        id:t='wnd_title';
        caption:t='yes';
        text:t='<<savePath>>'
      }

      Button_close { id:t = 'btn_back' }
    }

    div {
      id:t='wnd_content'
      size:t='pw, ph'

      div { //avatars list
        id:t='avatars_list'
        size:t='fw, ph'
        flow:t='h-flow'
        overflow-y:t='auto'

        behaviour:t='posNavigator'
        moveX:t='linear'
        moveY:t='linear'
        navigatorShortcuts:t='full'
        on_select:t='onAvatarSelect'

        <<#avatars>>
        tdiv {
          margin:t='0.01@sf'

          activeText {
            width:t='@profileUnlockIconSize'
            tinyFont:t='yes'
            text:t='<<name>>'
          }
          _newline {}

          tdiv {
            size:t='@profileUnlockIconSize, @profileUnlockIconSize'
            behaviour:t='bhvAvatar'
            value:t='<<name>>'
            isFull:t='yes'
          }

          tdiv {
            width:t='@dIco'
            margin-left:t='0.005@sf'
            flow:t='vertical'

            tdiv {
              id:t='small_icon'
              size:t='pw, pw'
              margin-bottom:t='0.005@sf'
              behaviour:t='bhvAvatar'
              value:t='<<name>>'
            }

            <<#isOnlyInGame>>
            img {
              size:t='pw, pw'
              background-image:t='#ui/gameuiskin#icon_primary_fail.svg'
              background-repeat:t='aspect-ratio'
              background-svg-size:t='pw, pw';
              tooltip:t='icon in game, but not found in resources'
            }
            <</isOnlyInGame>>

            <<#isOnlyInResources>>
            img {
              size:t='0.75pw, 0.75pw'
              background-image:t='#ui/gameuiskin#new_icon'
              background-repeat:t='aspect-ratio'
              tooltip:t='icon in resources, but not added to game yet'
            }
            <</isOnlyInResources>>

            <<#isPkgDev>>
            img {
              size:t='0.75pw, 0.75pw'
              background-image:t='#ui/gameuiskin#unit_under_construction'
              background-repeat:t='repeat-x'
              tooltip:t='icon in pkg_dev'
            }
            <</isPkgDev>>
          }
        }
        <</avatars>>
      }

      div { //edit block
        height:t='ph'
        padding:t='0.03@sf, 0'
        flow:t='vertical'

        activeText {
          id:t='sel_name'
          width:t='@profileUnlockIconSize'
          text:t='cardicon_default'
        }

        tdiv {
          id:t='sel_big_icon'
          size:t='2@profileUnlockIconSize, 2@profileUnlockIconSize'
          behaviour:t='bhvAvatar'
          value:t='0'
          isFull:t='yes'

          div {
            size:t='pw + 0.06@sf, ph + 0.06@sf'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            behaviour:t='button'
            on_pushed:t='onEditStart'
            on_repeat:t='onEditRepeat'
            on_click:t='onEditDone'
          }

          tdiv {
            id:t='edit_border'
            position:t='absolute'
            border:t='yes'; border-color:t='@red';
            display:t='hide'
          }

          div {
            id:t='main_border'
            position:t='absolute'
            border:t='yes'; border-color:t='@yellow'
            application-window:t='yes'

            moveElem {
              size:t='pw-10, ph-10'
              pos:t='5,5'
              position:t='absolute'
            }
          }
        }

        tdiv {
          id:t='sel_small_icon'
          size:t='2@dIco, 2@dIco'
          margin-top:t='0.01@sf'
          behaviour:t='bhvAvatar'
          value:t='0'
        }

        <<#sliders>>
        tdiv {
          text { text:t='<<id>>: ' }
          activeText { id:t='<<id>>_text'; text:t='' }
        }
        <</sliders>>

        tdiv {
          Button_text {
            showConsoleImage:t='no'
            text:t = 'Reset'
            on_click:t = 'onReset'
          }

          Button_text {
            showConsoleImage:t='no'
            text:t = 'Restore'
            on_click:t = 'onRestore'
          }
        }

        tdiv { height:t='fh' }

        Button_text {
          showConsoleImage:t='no'
          text:t = 'Save all'
          on_click:t = 'onSave'
        }
      }
    }
  }

  timer
  {
    id:t = 'edit_update'
    timer_handler_func:t = 'onEditUpdate'
  }
}
