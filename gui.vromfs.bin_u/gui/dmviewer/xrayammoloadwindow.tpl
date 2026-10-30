tdiv {
  id:t='ammo_load_popup_nest'

  popup_menu {
    id:t='ammo_load_popup'
    position:t='relative'
    flow:t='vertical'
    not-input-transparent:t='yes'
    css-hier-invalidate:t='yes'
    order-popup:t='yes'

    div {
      id:t='unit_weapons_selector'
      position:t='relative'
    }

    CheckBox {
      id:t='dmviewer_show_loaded_ammo'
      class:t='with_textarea'
      on_change_value:t='onShowLoadedAmmoChange'
      value:t='<<#isShowLoadedAmmo>>yes<</isShowLoadedAmmo>><<^isShowLoadedAmmo>>no<</isShowLoadedAmmo>>'
      width:t='pw'
      margin-top:t='1@blockInterval'
      CheckBoxImg {}
      textareaNoTab {
        text:t='#mainmenu/btnShowLoadedAmmo'
      }

      tdiv {
        pos:t='0, 50%ph - 50%h'
        position:t='relative'
        textareaNoTab {
          id:t='dmviewer_loaded_ammo_count'
          overlayTextColor:t='<<#isShowLoadedAmmo>>active<</isShowLoadedAmmo>><<^isShowLoadedAmmo>>faded<</isShowLoadedAmmo>>'
          input-transparent:t='yes'
          text:t=''
        }
      }
    }
  }
}