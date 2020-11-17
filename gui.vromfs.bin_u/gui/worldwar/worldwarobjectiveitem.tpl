<<#objectiveBlock>>
objectiveBlock {
  id:t='<<id>>_objectives'
  flow:t='vertical'
  width:t='pw'
  <<#hide>>
    display:t='hide'
    enable:t='no'
  <</hide>>

  header {
    cardImg {
      margin-left:t='1@headerIndent'
      background-image:t="<<countryIcon>>"
      valign:t='center'
    }
    text {
      margin-left:t='1@blockInterval'
      text:t='#worldWar/objectivesHeader/<<id>>'
      valign:t='center'
    }
    <<#isPrimary>>
    <<#reqFullMissionObjectsButton>>
    tdiv {
      size:t='fw, ph'
      margin-right:t='1@blockInterval'

      tdiv {
        height:t='ph'
        left:t='pw-w'
        position:t='relative'

        frameBlock_dark{
          height:t='ph'
          hasBorder:t='no'
          padding:t='1@dp, 0'

          Button_text {
            id:t = 'btn_tasks_list'
            showConsoleImage:t='no'
            reduceMinimalWidth:t='yes'
            useParentHeight:t='yes'
            noMargin:t='yes'
            tooltip:t = '#mainmenu/tasksList'
            _on_click:t = 'onOpenFullMissionObjects'

            btnText {
              text:t='#icon/info'
              padding:t='1@blockInterval, 0'
            }

            <<#unseenIcon>>
            unseenIcon {
              value:t='<<unseenIcon>>'
              valign:t='center'
            }
            <</unseenIcon>>
          }
        }
        <<#hiddenObjectives>>
        textareaNoTab {
          margin:t='1@blockInterval, 0'
          valign:t='center'
          text:t='<<?keysPlus>><<hiddenObjectives>> <<?worldWar/objectives/more>>'
        }
        <</hiddenObjectives>>
      }
    }
    <</reqFullMissionObjectsButton>>
    <</isPrimary>>
  }
  body {
    id:t='<<id>>_objectives_list'
    width:t='pw'
    flow:t='vertical'

    include "gui/worldWar/operationString"
  }

  <<#isPrimary>>
  textareaNoTab {
    id:t='afk_lost'
    max-width:t='pw'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    text:t=''
    smallFont:t='yes'
  }
  <</isPrimary>>
}
<</objectiveBlock>>
