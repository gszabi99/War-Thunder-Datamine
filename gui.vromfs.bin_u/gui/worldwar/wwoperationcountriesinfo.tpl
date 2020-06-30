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
      on_select:t='onCountrySelect'
      on_wrap_up:t='onWrapUp'
      on_wrap_down:t='onWrapDown'
      on_wrap_right:t='onWrapDown'
      <<#sides>>
      tdiv {
        include "gui/worldWar/countriesListWithQueue"
      }
      <</sides>>

    }

    tdiv {
      id:t='dummy_buttons_list'
      DummyButton {
        id:t='btn_join_battles'
        countryId:t=''
        btnName:t='X'
        on_click:t='onBattlesBtnClick'
      }
      DummyButton {
        id:t='btn_join_queue'
        countryId:t=''
        btnName:t='Y'
        on_click:t='onJoinQueue'
      }
      DummyButton {
        id:t='btn_leave_queue'
        countryId:t=''
        btnName:t='Y'
        on_click:t='onLeaveQueue'
      }
      DummyButton {
        id:t='btn_join_clan_operation'
        countryId:t=''
        btnName:t='Y'
        on_click:t='onJoinClanOperation'
      }
    }
  }
}
