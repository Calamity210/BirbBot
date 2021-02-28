import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Birb/lexer/lexer.dart';
import 'package:Birb/parser/parser.dart';
import 'package:Birb/runtime/runtime.dart';
import 'package:BirbBot/keys.dart';
import 'package:nyxx/Vm.dart';
import 'package:nyxx/nyxx.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/fuzzy.dart';

void main() {
  configureNyxxForVM();

  final bot = Nyxx(BOT_TOKEN, ignoreExceptions: false);

  bot.onReady.listen((event) {
    print('Birb bot ready to screm!');

    bot.onMessageReceived.listen((msg) async {
      if (msg.message?.content != null &&
          msg.message.content.startsWith('>birb')) {
        try {
          await runBirb(msg);
        } catch (e) {
          await msg.message.channel
              .send(content: 'Birb ran into an error, please try again.');
        }
      } else if (msg.message?.content != null &&
          msg.message.content.startsWith('>update')) {
        final sw = Stopwatch()..start();
        final mesg = await msg.message.channel.send(content: 'Updating...');
        try {
          await Process.start('pub', ['upgrade'], runInShell: true)
            ..stderr.listen((e) async {
              await mesg.edit(
                  content:
                      'Update failed in ${sw.elapsedMilliseconds / 1000}s');
            });
          sw.stop();
          await mesg.edit(
              content:
                  'Update completed successfully in ${sw.elapsedMilliseconds / 1000}s');
          exit(0);
        } catch (e) {
          sw.stop();
          await mesg.edit(
              content: 'Update failed in ${sw.elapsedMilliseconds / 1000}s');
        }
      } else if (RegExp(r'>\[(.+)\]').hasMatch(msg.message.content)) {
        await getBirbDocs(msg,
            RegExp(r'>\[(.+)\]').firstMatch(msg.message.content).group(1));
      }
    });
  });
}

Future<void> runBirb(MessageReceivedEvent msg) async {
  final content = msg.message.content.replaceFirst(RegExp(r'>birb\s+'), '');
  if (content.startsWith('```\s')) {
    final program = content.replaceAll('```', '');

    await runZoned(() async {
      try {
        final lexer = initLexer(program);
        final parser = initParser(lexer);
        final runtime = initRuntime(null);
        final node = parse(parser);
        await visit(runtime, node);
      } catch (e) {
        await msg.message.channel.send(content: e.toString());
      }
    }, zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) async {
      try {
        await msg.message.channel.send(content: line);
      } catch (e) {
        await msg.message.channel
            .send(content: 'Birb ran into an error, try again');
      }
    }));
  } else {
    final em = EmbedBuilder()
      ..color = DiscordColor.red
      ..title = 'Incorrect program format'
      ..description = '''
      To run a birb program, the program must be formatted as the following: 
    \\`\\`\\`
      Code goes here
    \\`\\`\\`
    Which should in turn look like:
    \`\`\`
      Code goes here
    \`\`\`
    ''';

    await msg.message.channel.send(embed: em);
  }
}

Future<void> getBirbDocs(MessageReceivedEvent msg, String arg) async {
  final response =
      (await http.get('https://birbolang.web.app/search-index.json')).body;
  final json = jsonDecode(response);

  final List documents = json['documents'];

  final fuse = Fuzzy(documents.map((e) => e['sectionTitle']).toList());
  final search = fuse.search(arg);
  final results = {};

  search.forEach((e) {
    final map =
        documents.firstWhere((d) => d['sectionTitle'] == e.matches.first.value);

    results[map['sectionTitle']] = map['sectionRoute'];
  });

  final embedBuilder = EmbedBuilder()
    ..color = DiscordColor.springGreen
    ..title = 'Found ${results.length} results for `$arg`';
  results.forEach((title, url) => embedBuilder.addField(
      name: title, content: 'https://birbolang.web.app$url'));

  await msg.message.channel.send(embed: embedBuilder);
}
