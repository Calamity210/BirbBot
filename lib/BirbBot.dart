import 'dart:async';

import 'package:Birb/utils/lexer.dart';
import 'package:Birb/utils/parser.dart';
import 'package:Birb/utils/runtime.dart';
import 'package:BirbBot/keys.dart';
import 'package:nyxx/Vm.dart';
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart';

void main() {
  configureNyxxForVM();

  var bot = Nyxx(BOT_TOKEN);

  bot.onReady.listen((event) {
    print('Birb bot ready to screm!');

    bot.onMessage.listen((msg) async {
      if (msg.message.content.startsWith('>birb')) {
        var content = msg.message.content.replaceFirst('>birb ', '');
        if (content.startsWith('```birb')) {

          final program =
              content.replaceAll('```birb', '').replaceAll('```', '');

          await runZoned(() async {
            try {
              var lexer = initLexer(program);
              var parser = initParser(lexer);
              var runtime = initRuntime();
              var node = parse(parser);
              await visit(runtime, node);
            } catch (e) {
              await msg.message.reply(mention: false, content:e.toString());
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
    });
  });

  CommandsFramework(bot, prefix: '>', admins: [Snowflake('302359032612651009')])
    ..registerServices([Service])
    ..discoverCommands();
}
