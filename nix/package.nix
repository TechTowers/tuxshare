{buildDartApplication}:
buildDartApplication rec {
  pname = "tuxshare";
  version = "1.0.0";

  src = ../.;

  autoPubspecLock = src + "/pubspec.lock";
}
