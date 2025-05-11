import "dart:convert";
import "dart:io";

import "package:ansix/ansix.dart";
import "package:tuxshare/tuxshare.dart";

final tuxshare = TuxShare(Platform.localHostname);

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

  for (var p in tuxshare.getPeers()) {
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
  await tuxshare.startListening();
  tuxshare.startDiscoveryLoop();
  await tuxshare.discover();

  ProcessSignal.sigint.watch().listen((_) {
    tuxshare.close();
    print("\nReceived SIGINT (Ctrl+C). Bye!".bold());
    exit(0);
  });

  final commands = <String, Future<void> Function(List<String>)>{
    "help": (args) async => print(help()),
    "discover": (args) async => await tuxshare.discover(),
    "list": (args) async => print(list()),
    "exit": (args) async {
      tuxshare.close();
      print("Bye!".bold());
      exit(0); // Immediate shell exit
    },
  };

  final Stream<String> lines = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  stdout.write("TuxShare> ".bold().yellow());
  await for (final String raw in lines) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    final command = parts[0];
    final args = parts.sublist(1);

    final handler = commands[command];
    if (handler != null) {
      try {
        await handler(args);
      } catch (e) {
        print("Error executing '$command': $e");
      }
    } else {
      print('Unknown command: "$command"');
    }

    stdout.write("TuxShare> ".bold().yellow());
  }
}
