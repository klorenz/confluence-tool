ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'page-prop-set [<query>] [<property>..]'
  desc: '''
    Add a label to selected pages.

  '''
  builder: (yargs) ->
    yargs
    .example '''
      $0 page-prop-set "label = foo" Type="Some Type" AnotherKey="AnotherValue"
    ''', "Set some page properties"

  handler: (argv) ->
    console.log argv
    process.exit()
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    properties = {}

    if argv.property.length
      for prop in argv.properties
        if m = prop.match /(.*?)=(.*)/
          properties[m[1]] = m[2]

      {page} = argv.query

      setPageProperties {page, properties}
      .then ->
        echo "ok"
        process.exit 0
      .catch (error) ->
        echo "#{error}"
        process.exit 1
    else
      didReadStdin.then (input) ->
        YAML.safeLoadAll input, (rec) ->
          if page
            if rec instanceof Array
              rec.map (value) -> value.page = page
            else
              rec.page = page

            if rec.cql
              delete rec.cql

          setPageProperties rec
