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
    client.addLabels client.resolveCQL(argv.query), argv.label, (page, data) =>
      if data.statusCode
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: error #{data.statusCode} #{data.message}\n"
      else
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: ok\n"
