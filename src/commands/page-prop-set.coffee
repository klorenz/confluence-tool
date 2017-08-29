ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'page-prop-set <query> [property..]'
  desc: '''
    Add a label to selected pages.

    Example:

      $0 page-prop-set "label = foo" -p Type "Some Type" -p AnotherKey AnotherValue
  '''

  builder: (yargs) ->
    yargs
    .option 'prop'
      alias: 'p'
      nargs: 2
      help: "this option takes two args NAME and VALUE"

  # builder: (yargs) ->
  #   yargs
  #   .option 'config',
  #     alias: 'c'
  #     demandCommand: false
  #     help: "configuration name, if you have multiple configurations"
  #     default: 'default'

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    client.addLabels client.resolveCQL(argv.query), argv.label, (page, data) =>
      if data.statusCode
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: error #{data.statusCode} #{data.message}\n"
      else
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: ok\n"
