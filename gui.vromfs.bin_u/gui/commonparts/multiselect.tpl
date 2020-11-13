MultiSelect {
  id:t='<<#multiSelectId>><<multiSelectId>><</multiSelectId>><<^multiSelectId>>multi_select<</multiSelectId>>'
  flow:t='<<#flow>><<flow>><</flow>><<^flow>>vertical<</flow>>'

  on_select:t='<<#onSelect>><<onSelect>><</onSelect>><<^onSelect>>onChangeValue<</onSelect>>'
  <<#isSimpleNavigationShortcuts>>
    navigatorShortcuts:t='yes'
  <</isSimpleNavigationShortcuts>>
  <<^isSimpleNavigationShortcuts>>
    navigatorShortcuts:t='cancel'
    _on_cancel_edit:t='<<#onCancelEdit>><<onCancelEdit>><</onCancelEdit>><<^onCancelEdit>>close<</onCancelEdit>>'
  <</isSimpleNavigationShortcuts>>

  value:t='<<value>>'
  snd_switch_on:t='<<#sndSwitchOn>><<snd_switch_on>><</sndSwitchOn>><<^sndSwitchOn>>choose<</sndSwitchOn>>'
  snd_switch_off:t='<<#sndSwitchOff>><<sndSwitchOff>><</sndSwitchOff>><<^sndSwitchOff>>choose<</sndSwitchOff>>'

  <<#needWrapNavigation>>
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'
  <</needWrapNavigation>>

  <<#list>>
  multiOption {
    <<^show>>
    enable:t='no'
    display:t='hide'
    <</show>>

    CheckBoxImg {}
    cardImg {
      margin-right:t='@blockInterval'
      background-image:t='<<icon>>'
      <<#color>>
      style:t='background-color:<<color>>;'
      <</color>>
      <<#size>>
      type:t='<<size>>'
      <</size>>
    }
    multiOptionText { text:t='<<text>>' }
  }
  <</list>>
}
