rootUnderPopupMenu {
  on_click:t='goBack';
  on_r_click:t='goBack';
  input-transparent:t='yes';
}

popup_menu {
  id:t='cluster_select';
  cluster_select:t='yes';
  menu_align:t='<<align>>';
  pos:t='<<position>>';
  position:t='root';
  total-input-transparent:t='yes';

  MultiSelect {
    id:t='cluster_multi_select';
    flow:t='vertical';
    on_select:t='onClusterSelect';
    navigatorShortcuts:t='cancel';
    _on_cancel_edit:t='goBack';

    <<#clusters>>
      multiOption {
        id:t='<<id>>';
        behavior:t='textarea';
        value:t='<<value>>';
        focusBtnName:t='A'
        text:t='<<text>>';
        cluster_option:t='yes';

        CheckBoxImg {}
      }
    <</clusters>>
  }
  popup_menu_arrow{}
}

dummy {
  on_click:t = 'goBack'
  behavior:t='accesskey'
  btnName:t='B'
}

