ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'search <query>'
  desc: '''
    find pages matching query.
  '''

  builder: (yargs) ->
    yargs
    .option 'yaml',
      demandCommand: false
      default: false
      help: "dump yaml data"

  handler: (argv) ->
    client = (new ConfigManager).getConfluenceAPI(argv.config)
    first  = true
    count = 0
    client.eachPage client.resolveCQL(argv.query), (page) ->
      if argv.yaml
        if not first
          process.stdout.write "--\n"
        process.stdout.write YAML.safeDump page
        first = false
      else
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}\n"

      count += 1
    .then ->
      process.stdout.write "\n-- #{count} pages found\n"

    .catch (error) ->
      process.stderr.write "\n#{error}\n"
      process.exit 1
