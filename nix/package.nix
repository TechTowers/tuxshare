{buildDartApplication}:
buildDartApplication rec {
  pname = "tuxshare";
  version = "1.1.0";
  src = ../.;

  dartEntryPoints."bin/tuxshare" = "bin/tuxshare.dart";
  autoPubspecLock = src + "/pubspec.lock";
}
