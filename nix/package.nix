{buildDartApplication}:
buildDartApplication rec {
  pname = "tuxshare";
  version = "0.1.0";
  src = ../.;

  dartEntryPoints."bin/tuxshare" = "bin/tuxshare.dart";
  autoPubspecLock = src + "/pubspec.lock";
}
