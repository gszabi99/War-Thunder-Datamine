tdiv {
  css-hier-invalidate:t='yes';
  padding-left:t='0.005@sf';

  <<#items>>
    button {
      behaviour:t='touchArea';
      id:t='<<id>>';
      size:t='0.06@sf, 0.06@sf';
      margin-left:t='0.005@sf';
      padding:t='0.003@sf';
      background-color:t='#77333333';
      img {
        background-image:t='<<image>>';
        size:t='pw, ph';
      }

      shortcut_id:t=<<action>>;
      on_click:t='::gcb.onShortcutOff';
      on_pushed:t='::gcb.onShortcutOn';
      touch-area-id:t='<<areaId>>'
    }
  <</items>>

}
