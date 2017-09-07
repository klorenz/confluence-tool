ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'label-add <query> <label..>'
  desc: '''
    Add a label to selected pages.
  '''

  # builder: (yargs) ->
  #   yargs

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    [labels, pagePropFilter] = client.getPagePropFilter argv.label

    query = {query: client.resolveCQL(argv.query), pagePropFilter}

    client.addLabels query, labels, (page, data) ->
      if data.statusCode
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: error #{data.statusCode} #{data.message}\n"
      else
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: ok\n"
    .then (result) ->
      process.exit 0
    .catch (error) ->
      if argv.debug
        process.stdout.write error.stack
      else
        process.stdout.write "#{error}"

      process.exit 1
