import "dart:convert";
import "dart:io";

import "package:ansix/ansix.dart";
import "package:tuxshare/tuxshare_peer.dart";

final peer = TuxSharePeer(Platform.localHostname);

String greeting() {
  return (StringBuffer()
        ..write(
          AnsiGrid.list(
            <Object?>[
              AnsiText(
                "TuxShare".bold(),
                style: AnsiTextStyle(bold: true),
                foregroundColor: AnsiColor.yellow,
                alignment: AnsiTextAlignment.center,
                padding: AnsiPadding.only(top: 1, bottom: 1),
              ),
              AnsiText(
                "Seamless Sharing. Everywhere.",
                foregroundColor: AnsiColor.silver,
                alignment: AnsiTextAlignment.center,
                padding: AnsiPadding.only(right: 1, left: 1),
              ),
            ],
            theme: const AnsiGridTheme(
              overrideTheme: true,
              border: AnsiBorder(
                type: AnsiBorderType.all,
                style: AnsiBorderStyle.rounded,
                color: AnsiColor.yellow,
              ),
            ),
          ),
        )
        ..write('\nType "help" for commands, "exit" to quit.\n')
        ..write("You are ${Platform.localHostname.yellow().bold()}"))
      .toString();
}

String help() {
  return (StringBuffer()..write(
        AnsiGrid.fromRows(
          <List<Object?>>[
            ["Command", "Description"],
            ["help", "displays this help message"],
            ["discover", "manually discover for all devices on the network"],
            ["list", "show available devices"],
            ["send [device] [file/folder]", "send a file to a device duh"],
            ["requests", "list all requests you received"],
            [
              "accept [request id]... <destination path>",
              "the request to accept",
            ],
            ["reject [request id|all]...", "reject one or every request"],
            ["exit", "exit shell"],
          ],
          theme: AnsiGridTheme(
            border: AnsiBorder(type: AnsiBorderType.none),
            headerTextTheme: AnsiTextTheme(
              style: AnsiTextStyle(bold: true, underline: true),
            ),
          ),
        ),
      ))
      .toString();
}

String list() {
  List<List<String>> hosts = [
    ["Host", "IP Address"],
  ];

  for (var p in peer.getPeers()) {
    hosts.add([p.hostname, p.address.address]);
  }

  return (StringBuffer()..write(
        AnsiGrid.fromRows(
          hosts,
          theme: AnsiGridTheme(
            border: AnsiBorder(
              type: AnsiBorderType.all,
              style: AnsiBorderStyle.rounded,
              color: AnsiColor.yellow,
            ),
            headerTextTheme: AnsiTextTheme(style: AnsiTextStyle(bold: true)),
          ),
        ),
      ))
      .toString();
}

Future<void> shell() async {
  print(greeting());
  await peer.startListening();
  peer.startDiscoveryLoop();
  await peer.discover();

  final Stream<String> lines = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  stdout.write("TuxShare> ".bold().yellow());
  await for (final String raw in lines) {
    final String cmd = raw.trim();
    if (cmd.isEmpty) {
      stdout.write("TuxShare> ".bold().yellow());
      continue;
    }

    switch (cmd) {
      case "discover":
        await peer.discover();
        break;
      case "list":
        print(list());
        break;
      case "help":
        print(help());
        break;
      case "exit":
        peer.close();
        print("Bye!".bold());
        return;
      default:
        print('Unknown command: "$cmd"');
    }

    stdout.write("TuxShare> ".bold().yellow());
  }
}
