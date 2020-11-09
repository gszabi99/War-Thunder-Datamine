  <<#squad>>
      expandable {
        class:t='simple'
        display:t='hide'
        selImg {
          flow:t='vertical'
          noPadding:t='yes'
          tdiv {
            width:t='pw'
            flow:t='vertical'

            tdiv {
              width:t='pw'
              height:t='1@buttonHeight'
              margin-bottom:t='1@blockInterval'

              Button_text {
                id:t = 'btn_user_options'
                height:t='ph'
                talign:t='left'
                visualStyle:t='noFrame'
                noMargin:t='yes'
                btnName:t=''
                leaderUid:t=''
                on_click:t = 'onLeaderClick'
                on_r_click:t='onLeaderClick'

                ButtonImg {
                  class:t='independent'
                  fullSizeIcons:t='yes'
                  btnName:t='Y'
                  showOnSelect:t='focus'
                }
                activeText {
                  id:t='leader_name'
                  pare-text:t='yes'
                  class:t='active'
                  valign:t='center'
                  overflow:t='hidden'
                  text:t='<<leader_name>>'
                }
              }
              tdiv {
                width:t='fw'
                height:t='ph'
                margin:t='1@blockInterval,0'

                text {
                  id:t='application_disabled'
                  width:t='pw'
                  position:t='relative'
                  pare-text:t='yes'
                  valign:t='center'
                  overflow:t='hidden'
                  display:t='hide'
                  text:t='#squad/application_disabled'
                }
              }
              textareaNoTab {
                id:t='num_members'
                left:t='pw-w'
                text:t='<<num_members>>'
                text-align:t='right'
                smallFont:t='yes'
              }
            }

            tdiv {
              width:t='pw'

              tdiv {
                id:t= 'buttons_container'
                padding:t='-1@blockInterval'

                <<#buttonsList>>
                <<@buttonsList>>
                <</buttonsList>>
              }
              textareaNoTab {
                id:t='presence'
                top:t='0.5ph-0.5h'
                position:t='relative'
                width:t='fw'
                text-align:t='right'
                text:t='<<presence>>'
              }
            }
          }

        }
      }
  <</squad>>