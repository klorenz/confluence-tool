ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'
{didReadStdin} = require '../util'

Yargs = null

module.exports =
  command: 'pagespec'
  desc: '''
    Show help on pagespec (page specification)
  '''
  builder: (yargs) ->
    Yargs = yargs
    .epilog '''
    You can specify a page using one of the following patterns:

    - "SPACE:page title" -> space = SPACE AND title = "page title"
    - :title             -> title = "title"
    - 123456             -> ID = 123456
    - label = "foo"      -> label = "foo"

    All the patterns are resolved to a CQL, which is then used to
    query pages.

    '''

  handler: (argv) ->
    #console.log argv
    Yargs.showHelp()
    process.exit(0)
