tdiv {
  id:t='shortcut_text';
  position:t='absolute';
  pos:t='pw/2 - w/2, -h';
  re-type:t='9rect';
  background-color:t='@white';
  background-repeat:t='expand';
  background-image:t='#ui/gameuiskin#block_bg_rounded_gray';
  background-position:t='4, 4, 4, 4';
  padding:t='0.002@shHud, 0.002@shHud, 0.002@shHud, 0';
  margin-bottom:t='0.004@shHud'
  width:t='1@hudActionBarItemSize';
  color-factor:t='192'
  textarea{
    pos:t='pw/2 - w/2';
    position:t='relative';
    text-align:t='center'
    <<^isLongScText>>hudFont:t='small';<</isLongScText>>
    <<#isLongScText>>hudFont:t='tiny';<</isLongScText>>
    shortcut:t='yes';
    text:t='<<shortcutText>>';
  }
}