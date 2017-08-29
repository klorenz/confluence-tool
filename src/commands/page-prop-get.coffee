ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'page-prop-get <query> <property..>'
  desc: '''
    Add a label to selected pages.
  '''

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)
