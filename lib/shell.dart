import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:ansix/ansix.dart";
import "package:dart_console/dart_console.dart";
import "package:tuxshare/peer_info.dart";
import "package:tuxshare/tuxshare_worker.dart";

final Set<PeerInfo> discoveredPeers = {}; // local peer cache
final Map<int, dynamic> receivedRequests = {}; // local request cache
final console = Console();

void prompt() => console.write("TuxShare> ".bold().yellow());

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
            ["clear", "clear your screen"],
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

String list(Set<PeerInfo> peers) {
  if (peers.isEmpty) {
    return "No peers found 😥".bold();
  }

  List<List<String>> hosts = [
    ["Host", "IP Address"],
  ];

  for (var p in peers) {
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
            headerTextTheme: AnsiTextTheme(
              style: AnsiTextStyle(bold: true),
              padding: AnsiPadding.horizontal(1),
            ),
            cellTextTheme: AnsiTextTheme(padding: AnsiPadding.horizontal(1)),
          ),
        ),
      ))
      .toString();
}

String requests() {
  if (receivedRequests.isEmpty) {
    return "No requests yet 😥".bold();
  }

  List<List<String>> rows = [
    ["ID", "Peer", "File", "Size", "Hash"],
  ];

  for (var requestID in receivedRequests.keys) {
    final request = receivedRequests[requestID];
    rows.add([
      requestID.toString(),
      request["peer"].toString(),
      File(request["file"]).uri.pathSegments.last,
      request["size"].toString(),
      request["hash"].toString(),
    ]);
  }

  return (StringBuffer()..write(
        AnsiGrid.fromRows(
          rows,
          theme: AnsiGridTheme(
            border: AnsiBorder(
              type: AnsiBorderType.all,
              style: AnsiBorderStyle.rounded,
              color: AnsiColor.yellow,
            ),
            keepSameWidth: false,
            headerTextTheme: AnsiTextTheme(
              style: AnsiTextStyle(bold: true),
              padding: AnsiPadding.horizontal(1),
            ),
            cellTextTheme: AnsiTextTheme(padding: AnsiPadding.horizontal(1)),
          ),
        ),
      ))
      .toString();
}

Future<void> shell() async {
  final workerReceivePort = ReceivePort();
  await Isolate.spawn(backendMain, workerReceivePort.sendPort);
  late SendPort workerSendPort;

  console.writeLine(greeting());

  workerReceivePort.listen((message) {
    if (message is SendPort) {
      workerSendPort = message;
    } else if (message is Map<String, dynamic>) {
      switch (message["type"]) {
        case "peerDiscovered":
          final peer = PeerInfo.fromJson(message['data']);
          discoveredPeers.add(peer);
          console.writeLine("Discovered peer: $peer".blue());
          prompt();
        case "peerForget":
          final peer = PeerInfo.fromJson(message['data']);
          discoveredPeers.remove(peer);
          console.writeLine("Forgot peer: $peer".blue());
          prompt();
        case "request":
          final requestID = message["data"].keys.first;
          final request = message["data"][requestID];
          final peer = discoveredPeers.firstWhere(
            (p) => p.hostname == request["peer"],
          );
          final data = message["data"];
          data[requestID]["peer"] = peer;
          receivedRequests.addAll(data);
          console.writeLine("Received a send request from $peer".blue());
          prompt();
        case "decline":
          final request = message["data"];
          final peer = request["peer"];
          console.writeLine("Request from $peer was declined.".red());
          prompt();
        case "fileReceived":
          final filePath = message['data'];
          console.writeLine("File received: $filePath".green());
          prompt();
        case "sendingFileError":
          final peer = PeerInfo.fromJson(message['data']['peer']);
          final error = message['data']['error'];
          final file = message['data']['file'];
          console.writeErrorLine(
            "Error sending file $file to $peer: $error".red(),
          );
          prompt();
        case "receivingFileError":
          final file = message['data']['file'];
          final error = message['data']['error'];
          console.writeErrorLine("Error receiving file $file: $error".red());
          prompt();
      }
    } else {
      console.writeErrorLine(message);
    }
  });

  ProcessSignal.sigint.watch().listen((_) {
    workerSendPort.send({"type": "exit"});
    console.writeLine("\nReceived SIGINT (Ctrl+C). Bye!".bold());
    exit(0);
  });

  final commands = <String, Future<void> Function(List<String>)>{
    "help": (args) async => console.writeLine(help()),
    "clear": (args) async => console.clearScreen(),
    "discover": (args) async => workerSendPort.send({"type": "discover"}),
    "list": (args) async => console.writeLine(list(discoveredPeers)),
    "send": (args) async {
      if (args.length < 2) {
        console.writeErrorLine('Usage: send [device] [file/folder]');
        return;
      }

      final target = args[0];
      final file = File(args.sublist(1).join(" "));
      try {
        await file.openRead().first;
      } catch (e) {
        throw FileSystemException(
          "File is not readable or does not exist: ",
          file.path,
        );
      }

      final peer = discoveredPeers.firstWhere(
        (p) => p.hostname == target || p.address.address == target,
        orElse: () => throw ArgumentError('Peer "$target" not found.'),
      );

      console.writeLine('Sending "${file.path}" to $peer...');
      workerSendPort.send({
        "type": "send",
        "data": {"peer": peer.toJson(), "file": file},
      });
    },
    "requests": (args) async => console.writeLine(requests()),
    "accept": (args) async {
      if (args.isEmpty) {
        console.writeErrorLine(
          'Usage: accept [request id]... <destination path>',
        );
        return;
      }

      final requestID = int.parse(args[0]);
      String destination = "";
      if (args.length > 1) {
        destination = args.sublist(1).join(" ");
      }
      if (!receivedRequests.containsKey(requestID)) {
        console.writeErrorLine('Request ID $requestID not found.');
        return;
      }

      workerSendPort.send({
        "type": "accept",
        "data": {
          "hash": receivedRequests[requestID]["hash"],
          "peer": receivedRequests[requestID]["peer"].toJson(),
          "destination": destination,
        },
      });
      receivedRequests.remove(requestID);
    },
    "decline": (args) async {
      if (args.length != 1) {
        console.writeErrorLine('Usage: decline [request id]');
        return;
      }

      final requestID = int.parse(args[0]);

      if (!receivedRequests.containsKey(requestID)) {
        console.writeErrorLine('Request ID $requestID not found.');
        return;
      }

      workerSendPort.send({
        "type": "decline",
        "data": {
          "hash": receivedRequests[requestID]["hash"],
          "peer": receivedRequests[requestID]["peer"].toJson(),
        },
      });
      receivedRequests.remove(requestID);
    },
    "exit": (args) async {
      workerSendPort.send({"type": "exit"});
      console.writeLine("Bye!".bold());
      exit(0); // Immediate shell exit
    },
    "": (args) async {},
  };

  final Stream<String> lines = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  prompt();
  await for (final String raw in lines) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    final command = parts[0];
    final args = parts.sublist(1);

    final handler = commands[command];
    if (handler != null) {
      try {
        await handler(args);
      } catch (e) {
        console.writeErrorLine("Error executing '$command': $e");
      }
    } else {
      console.writeErrorLine('Unknown command: "$command"');
    }

    prompt();
  }
}
