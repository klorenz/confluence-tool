ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'
{didReadStdin} = require '../util'

gYargs = null

module.exports =
  command: 'page-prop-set [<page>] [<property>..]'
  desc: '''
    Add a label to selected pages.

  '''
  builder: (yargs) ->
    gYargs = yargs
    .option 'parent',
      alias: 'p'
    .example '''
        $0 page-prop-set "label = foo" Type="Some Type" AnotherKey="AnotherValue"
      ''', "Set some page properties"
    .epilog '''
      You either specify query and properties with arguments or you pass a YAML
      file from stdin.  You may also pass the query via command line and properties
      via stdin.  Format of YAML file is:

      * `page`, can be any pagespec.  Run "$0 pagespec" for more
        info

      * `templates`, {Object}
        * `name`
        * `data`

      * `partials` - these you can reference also as templates and like {{> name}}
        * `name`
        * `data`

      * `properties` {Object} with names as keys.  Values may be either {String}
         or {Object}:

        * `value` - set parameter to this value
        * `type`  - type of value, may be 'user', 'page', 'link', they will set
          corresponding templates to render data correctly
        * 'template' - if set, then value is rendered using template given in
          templates
      '''

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    properties = {}

    setPageProperties = (page, rec) ->
      if page
        if rec instanceof Array
          rec.map (value) -> value.page = page
        else
          rec.page = page

        if rec.cql
          delete rec.cql

      if argv.parent
        rec.parent = argv.parent

      console.log "rec", rec

      client.setPageProperties rec, (value) ->
        process.stdout.write "updated page #{value.space.key}:#{value.title}\n"

      .then (values) ->
        process.stdout.write "-- #{values.length} pages updated\n"
        process.exit(0)

      .catch (error) ->
        if argv.debug
          process.stderr.write error.stack
          if error.data
            console.log error.data

        process.stdout.write "#{error}\n"
        process.exit(1)

    page = argv.page

    if argv.property.length
      for prop in argv.property
        if m = prop.match /(.*?)=(.*)/
          properties[m[1]] = m[2]

      setPageProperties page, {properties}

    else
      x = setTimeout (->
        gYargs.showHelp()
        process.exit(1)
      ), 1000

      didReadStdin
      .then (input) ->
        YAML.safeLoadAll input, (rec) ->
          clearTimeout x
          console.log rec

          setPageProperties page, rec
      .catch (error) ->
        if argv.debug
          process.stderr.write error
        process.stdout.write "#{error}\n"
        process.exit 1
