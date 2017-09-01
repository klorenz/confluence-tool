ConfigManager = require '../config-manager.coffee'
YAML = require 'js-yaml'

module.exports =
  command: 'update [<pagespec>] [<content>] [options]'
  describe: 'update a page'
  builder: (yargs) ->
    yargs
    .option 'title',
      alias: 't'
      help: "new title of page"

    .option 'version',
      alias: 'v'
      help: "current version of page"

    .example '$0 update "SOME:Page Title" "Wiki Content"',
      "Update page with wiki content"
    .example '$0 update 12345678 "<p>storage format</p>"',
      "update page specified by ID with storage format"
    .example '''cat somefile_containing_body | $0 update 'space = SOME AND title = "Page Title"' ''',
      "update page found by CQL with body from stdin"
    .example "cat somefile.yaml | $0 update",
      "update one or many pages from stdin (in YAML format)"
    .example '$0 update "SOME:Page Title" -t "new title"',
      "rename a page"

    .epilog '''
      Format of YAML file in case you want to update multiple pages (supports multidoc):

      ```yaml
      page: SOME:Page Title
      newBody: "new body"
      ---
      -
        page: 1234567
        title: "new title"
        version: 4          # current version
      -
        page: SOME:Page Title
        newBody: "<p>some body</p>"
      ```

      Page is always resolved to ID and missing fields are filled from the queried
      current version.  If you specify the version you are sure, that change will
      not be performed in case there was an edit in between to create a newer
      version.
    '''

  handler: (argv) ->
    config = new ConfigManager
    client = config.getConfluenceAPI(argv.config)

    updatePage (pagespec, content) ->
      cql = client.resolveCQL pagespec
      @updatePage
      content

    if argv.pagespec
      if argv.content
        updatePage

    client.addLabels client.resolveCQL(argv.query), argv.label, (page, data) =>
      if data.statusCode
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: error #{data.statusCode} #{data.message}\n"
      else
        process.stdout.write "#{page.id} #{page.spaceKey} #{page.title}: ok\n"
