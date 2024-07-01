actionBarItemTextShortcut {
  id:t='shortcut_text';
  position:t='absolute';
  pos:t='pw/2 - w/2, -h';
  re-type:t='9rect';
  background-color:t='#C0FFFFFF';
  background-repeat:t='expand';
  background-image:t='#ui/gameuiskin#block_bg_rounded_gray';
  background-position:t='4, 4, 4, 4';
  padding:t='0.002@shHud, 0.002@shHud, 0.002@shHud, 0';
  margin-bottom:t='0.004@shHud'
  min-height:t='@hudActionBarTextShHight'
  textarea{
    pos:t='pw/2-w/2, ph/2-h/2';
    position:t='relative';
    text-align:t='center'
    <<^isLongScText>>hudFont:t='small';<</isLongScText>>
    <<#isLongScText>>hudFont:t='tiny';<</isLongScText>>
    shortcut:t='yes';
    text:t='<<shortcutText>>';
  }
  <<#hasSecondActionsBtn>>
  img {
    position:t='absolute'
    id:t='actionCollapseBtn'
    background-image:t='#ui/gameuiskin#icon_collapse_action_bar.svg'
    <<#isCloseSecondActionsBtn>>
      rotation:t='180'
    <</isCloseSecondActionsBtn>>
    <<^isCloseSecondActionsBtn>>
      rotation:t='0'
    <</isCloseSecondActionsBtn>>
    background-repeat:t='aspect-ratio'
    pos:t='2@sf/@pf, (ph - h)/2'
    size:t='12@sf/@pf, 16@sf/@pf'
  }
  <</hasSecondActionsBtn>>
}