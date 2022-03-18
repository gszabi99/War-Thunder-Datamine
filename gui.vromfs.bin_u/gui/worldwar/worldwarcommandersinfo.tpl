<<^useSwitchMode>>
tdiv {
  size:t='pw, fh'

  <<#groups>>
    tdiv {
      size:t='pw/<<groupsNum>>, ph'
      flow:t='vertical'

      tdiv {
        size:t='pw, 0.04@sf'
        padding:t='0, 1@framePadding'
        background-color:t='@objectiveHeaderBackground'

        <<#armyCountryImg>>
          cardImg {
            id:t='img_country_army'
            background-image:t='<<image>>'
            pos:t='1@headerIndent, 50%ph-50%h'
            position:t='relative'
          }
        <</armyCountryImg>>
        text {
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          margin-left:t='1@blockInterval'
          text:t='<<teamText>>'
        }
      }

      tdiv {
        margin:t='1@headerIndent, 1@framePadding'
        flow:t='vertical'

        include "%gui/worldWar/worldWarMapArmyItem"
      }
    }
  <</groups>>
}
<</useSwitchMode>>

<<#useSwitchMode>>
HorizontalListBox {
  id:t='commanders_switch_box'
  size:t='1@wwMapPanelInfoWidth, 0.04@sf'
  on_select:t = 'onSwitchCommandersSide'
  withImages:t='yes'
  <<@switchBoxItems>>
}
tdiv {
  id:t='switch_mode_items_place'
  size:t='1@wwMapPanelInfoWidth, fh'
  flow:t='vertical'

  tdiv {
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    width:t='0.9pw'
    flow-align:t='center'
    flow:t='h-flow'
    <<#groups>>
      include "%gui/worldWar/worldWarMapArmyItem"
    <</groups>>
  }
}
<</useSwitchMode>>
