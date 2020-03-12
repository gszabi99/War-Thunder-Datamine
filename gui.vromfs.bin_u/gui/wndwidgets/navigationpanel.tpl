tdiv {
  id:t = 'panel';
  width:t = '<<panelWidth>><<^panelWidth>>0.3@sf<</panelWidth>>';
  height:t = 'ph';
  flow:t = 'horizontal';
  overflow-y:t = 'auto';
  total-input-transparent:t='yes'

  tdiv {
    size:t = 'fw, fh';
    flow:t = 'vertical';

    tdiv {
      id:t = 'panel_header';
      width:t = 'fw';
      height:t = '<<headerHeight>><<^headerHeight>>0.05@sf<</headerHeight>>';
      margin-left:t   = '<<headerOffsetX>>';
      margin-right:t  = '<<headerOffsetX>>';
      margin-top:t    = '<<headerOffsetY>>';
      margin-bottom:t = '<<headerOffsetY>>';
      flow:t = 'horizontal';

      textareaNoTab {
        width:t = 'fw';
        padding:t = '0.01@sf, 0';
        overflow:t = 'hidden';
        caption:t = 'yes'
        text-align:t = 'center';
        valign:t = 'center';
        text:t    = '#mainmenu/navigation';
        tooltip:t = '#mainmenu/navigation';
      }

      <<#needShowCollapseButton>>
        emptyButton {
          id:t = 'collapse_button';
          class:t = 'navigationCollapse';
          height:t = '1@buttonHeight';
          tooltip:t = '#mainmenu/btnCollapse';
          <<#collapseShortcut>>
            btnName:t = '<<collapseShortcut>>';
          <</collapseShortcut>>
          on_click:t = 'onCollapse';
          icon {
            rotation:t = '270';
          }
          ButtonImg {}
        }
      <</needShowCollapseButton>>
    }

    listboxNoScroll {
      id:t = 'nav_list';
      class:t = 'navigationItemList';
      size:t = 'pw, fh';
      on_wrap_up:t = 'onWrapUp';
      on_wrap_down:t = 'onWrapDown';
      on_click:t = 'onNavClick';
      <<#navShortcutGroup>>
        nav_btn_group:t = '<<navShortcutGroup>>'
      <</navShortcutGroup>>
    }
  }

  chapterSeparator {}
}

DummyButton {
  behavior:t = 'accesskey';
  on_click:t = 'onNavPrev';
  <<#prevShortcut>>
    btnName:t = '<<prevShortcut>>';
  <</prevShortcut>>
}

DummyButton {
  behavior:t = 'accesskey';
  on_click:t = 'onNavNext';
  <<#nextShortcut>>
    btnName:t = '<<nextShortcut>>';
  <</nextShortcut>>
}

emptyButton {
  id:t = 'expand_button';
  class:t = 'navigationExpand';
  position:t = 'absolute';
  left:t = '<<headerOffsetX>>';
  top:t  = '<<headerOffsetY>>';
  height:t = '1@buttonHeight';
  tooltip:t = '#mainmenu/navigationExpand';
  <<#expandShortcut>>
    btnName:t = '<<expandShortcut>>'
  <</expandShortcut>>
  on_click:t = 'onExpand';
  ButtonImg {}
  icon {
    rotation:t = '90';
  }
}
