ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

Yargs = null

module.exports =
  command: 'page-prop-get <query> [<property>..]'
  desc: '''
    Add a label to selected pages.
  '''
  builder: (yargs) ->
    Yargs = yargs

    .option 'raw',
      default: false
      describe: "display raw HTML code"

    .option 'output-type',
      describe: "type of data to get from confluence"
      choices: ['view', 'storage']
      default: 'view'

    .option 'data',
      describe: """
        If not `--raw`, extract user and link-data into dictionary:
        - `value` - usual value
        - `html` - original HTML code
        - `users` - Array of users referred in value
        - `refs` - Array of page references in value
        - `links` - Array of external links in value
        """
      default: false


  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    opts = {}

    if argv.raw
      opts.stripTags = false

    if argv.outputType
      opts.outputType = argv.outputType

    if argv.data
      opts.data = argv.data

    if not argv.query
      Yargs.showHelp
      process.exit 1

    [keys, matches] = client.getPagePropFilter(argv.property)

    if keys.length
      opts.keys = keys
    if matches.length
      opts.pagePropFilter = matches

    #console.log "opts", opts
    first = true
    client.getPageProperties client.resolveCQL(argv.query), opts, (properties, page) =>
      {id, spaceKey, title} = page

      if not first
        process.stdout.write "---\n"
      else
        first = false

      process.stdout.write YAML.safeDump {id, spaceKey, title, properties}
    .then ->
      process.exit(0)
    .catch (error) ->
      if argv.debug
        console.log error.stack

      console.log "#{error}"
      process.exit(1)
