import 'package:BirbBot/keys.dart';
import 'package:BirbBot/lang/lexer.dart';
import 'package:BirbBot/lang/parser.dart';
import 'package:nyxx/Vm.dart';
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart';

import 'lang/runtime.dart';

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
          var lexer = initLexer(program);
          var parser = initParser(lexer);
          var runtime = initRuntime(msg.message);
          var node = parse(parser);
          await visit(runtime, node);

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
