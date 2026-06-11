// Home 页音乐与星星定位常量。
//
// 说明：
// - 曲目索引按 `DateTime.now().day % 10` 轮换
// - 设计稿坐标基于 393x852，星星锚点为中心点

const double kHomeDesignWidth = 393;
const double kHomeDesignHeight = 852;

const double kMusicStarCenterXDesign = 52;
const double kMusicStarCenterYDesign = 670; // 852 - 182
const double kMusicStarHitRadiusDesign = 24;

const List<String> kHomeMusicTracks = <String>[
  'bach-prelude-c-major.mp3',
  'canon-in-d.mp3',
  'chopin-nocturne-20-in-c-sharp-minor.mp3',
  'chopin-nocturne-op-9-no-2.mp3',
  'claire-de-lune-debussy.mp3',
  'gymnopedie-n1.mp3',
  'saint-saens-le-carnaval-des-animaux-1886-piano-9290.mp3',
  'schumann-kinderszenen.mp3',
  'tunetank-classical-piano-music-1.mp3',
  'tunetank-classical-piano-waltz.mp3',
];

int homeMusicIndexForDate(DateTime date) {
  return date.day % kHomeMusicTracks.length;
}

String homeMusicAssetPath(int index) {
  if (index < 0 || index >= kHomeMusicTracks.length) {
    throw RangeError.range(index, 0, kHomeMusicTracks.length - 1, 'index');
  }
  return 'audio/home_music/${kHomeMusicTracks[index]}';
}
