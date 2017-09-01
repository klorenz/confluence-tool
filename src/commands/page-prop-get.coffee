ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'page-prop-get <query> [<property>..]'
  desc: '''
    Add a label to selected pages.
  '''

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    opts = {}
    if argv.property.length
      opts.keys = argv.property

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
      console.log "#{error}"
      process.exit(1)
