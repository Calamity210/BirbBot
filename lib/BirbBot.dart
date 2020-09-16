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

void main() {
  configureNyxxForVM();

  var bot = Nyxx(BOT_TOKEN, ignoreExceptions: false);

  bot.onReady.listen((event) {
    print('Birb bot ready to screm!');

    bot.onMessage.listen((msg) async {
      if (msg.message.content.startsWith('>birb')) {
        await runBirb(msg);
      } else if (RegExp('>(.+)<').hasMatch(msg.message.content)) {
        await getBirbDocs(
            msg, RegExp('>(.+)<').firstMatch(msg.message.content).group(1));
      }
    });
  });
}

Future<void> runBirb(MessageEvent msg) async {
  var content = msg.message.content.replaceFirst(RegExp(r'>birb[\s]+'), '');
  if (content.startsWith('```birb')) {
    final program = content.replaceAll('```birb', '').replaceAll('```', '');

    await runZoned(() async {
      try {
        var lexer = initLexer(program);
        var parser = initParser(lexer);
        var runtime = initRuntime(null);
        var node = parse(parser);
        await visit(runtime, node);
      } catch (e) {
        await msg.message.reply(mention: false, content: e.toString());
      }
    }, zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) async {
      await msg.message.reply(mention: false, content: line);
    }));
  } else {
    final em = EmbedBuilder()
      ..color = DiscordColor.red
      ..title = 'Incorrect program format'
      ..description =
          '''To run a birb program, the program must be formatted as the following: 
    \\`\\`\\`birb
      Code goes here
    \\`\\`\\`
    Which should in turn look like:
    \`\`\`birb
      Code goes here
    \`\`\`
    ''';

    await msg.message.reply(embed: em, mention: false);
  }
}

Future<void> getBirbDocs(MessageEvent msg, String arg) async {
  final response =
      (await http.get('https://gc.spidev.codes/assets/js/search-data.json'))
          .body;
  var json = jsonDecode(response);
  var results = {};
  List splitArg = arg.split('${arg[arg.length ~/ 2]}');
  final wildMatch = RegExp('${splitArg[0]}\w+|${splitArg[1]}\w+');

  json.values.forEach((data) {
    if (data['title'] == arg)
      results[arg] = data['url'];
    else if (data['content'].contains(arg))
      results[data['title']] = data['url'];
    else if (wildMatch.hasMatch(data['title']) ||
        wildMatch.hasMatch(data['content']))
      results[data['title']] = data['url'];
  });

  var embedBuilder = EmbedBuilder()
    ..color = DiscordColor.springGreen
    ..title = 'Found ${results.length} results for `$arg`';
  results.forEach((title, url) => embedBuilder.addField(
      name: title, content: 'https://gc.spidev.codes/$url'));

  await msg.message.reply(mention: false, embed: embedBuilder);
}
