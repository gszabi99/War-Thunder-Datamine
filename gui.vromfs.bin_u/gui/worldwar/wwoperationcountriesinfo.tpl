tdiv {
  pos:t='0.5pw-0.5w, 0'
  flow:t='vertical'
  tdiv {
    pos:t='0.5pw-0.5w, 0'
    flow:t='horizontal'
    textAreaCentered {
      pos:t='0.5pw-0.5w, 0'
      position:t='absolute'
      text-align:t='center'
      text:t='<<vsText>><<^vsText>>#country/VS<</vsText>>'
    }

    tdiv {
      id:t='countries_container'
      width:t='1@WWOperationDescriptionWidth'
      pos:t='0.5pw-0.5w, 0'
      position:t='relative'
      behaviour:t='posNavigator'
      navigatorShortcuts:t='yes'
      css-hier-invalidate:t='yes'
      total-input-transparent:t='yes'
      <<#sides>>
      wwConflictSideBlock {
        include "gui/worldWar/countriesListWithQueue"
      }
      <</sides>>
    }

    DummyButton {
      btnName:t='X'
      on_click:t='onToBattles'
    }
    DummyButton {
      btnName:t='Y'
      on_click:t='onMapSideAction'
    }
  }
}
