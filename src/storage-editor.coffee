cheerio = require 'cheerio'
{isHtml} = require './util'

transformNamespaces = (src,dst,elements) ->
  re = new RegExp("(.*)#{src}(.*)")

  elements.each ->
    if mob = @name.match re
      @name = mob[1] + dst + mob[2]
      if mob[1] not in knownNamespaces
        knownNamespaces.push mob[1]

    keys = (k for k of @attribs)

    for k in keys
      if mob = k.match re
        name = mob[1] + dst + mob[2]
        @attribs[name] = @attribs[k]
        delete @attribs[k]

        if mob[1] not in knownNamespaces
          knownNamespaces.push mob[1]

  elements

fixHtml = (s) ->
  if isHtml s
    data = cheerio.load s, xmlMode: true
    transformNamespaces ":", "--", data('*')
    data.html()
  else
    s

cleanHtml = (s) ->
  data = cheerio.load s, xmlMode: true
  transformNamespaces "--", "*", data('*')
  data.html()

knownNamespaces = []

# This is a workaround, such that cheerio understands namespace CSS selectors.
#
cheerioOrig = {}

# translate selectors
cheerioOrig['find'] = cheerio::find
cheerio::find = (selector) ->
  if typeof selector isnt 'string'
    debugger
  #console.log "this", this, "selector", selector, knownNamespaces
  selector = selector.replace /(\w+)\|(\w+)/g, (m, ns, tag) ->
    "#{ns}--#{tag}"
    # if ns in knownNamespaces
    #   "#{ns}--#{tag}"
    # else
    #   m
  #console.log "selector after", selector
  cheerioOrig['find'].call this, selector

cheerioOrig['attr'] = cheerio::attr
cheerio::attr = (name, value) ->
  name = name.replace ":", "--"
  #name = name.replace "|", "--"
  cheerioOrig['attr'].call this, name, value

# make sure, that new HTML content is also internally transformed to be
# selectible with namespace CSS selectors
for method in ['append', 'prepend', 'after', 'before', 'replaceWith']
  do (method) ->
    cheerioOrig[method] = cheerio::[method]
    cheerio::[method] = (args...) ->
      args = args.map (arg) -> fixHtml arg
      cheerioOrig[method].call this, args...

for method in ['html']
  do (method) ->
    cheerioOrig[method] = cheerio::[method]
    cheerio::[method] = (args...) ->
      if args.length
        args = args.map (arg) -> fixHtml arg
      result = cheerioOrig[method].call this, args...
      cleanHtml result


# Public: provide a jQuery-like storage-format editor
#
# ```coffee
#   {StorageEditor} = require 'atlassian-confluence-api'
#   editor = new StorageEditor
#   $ = editor.beginEdit(content)
#   # append a '.' to all paragraphs
#   $('p').append(".")
#   newContent = editor.endEdit()
# ```
#
# This uses cheerio.  With the extension, that you can use xml namespace
# CSS selectors to select items, e.g. "ac|structured-macro" or "ri|link".
# For doing this, you must start your edit with editor's beginEdit() method
# and get the data back with endEdit().
#
class StorageEditor
  constructor: ->
    @handlebars = require 'handlebars'
    @templates = {}
    @initialize()

  # Public: get only a jquery object
  @jQuery: (content) ->
    (new StorageEditor).beginEdit(content)

  addTemplate: (name, template) ->
    @templates[name] = @handlebars.compile template

  applyTemplate: (name, data) ->
    @templates[name](data)

  addPartial: (name, template) ->
    @templates[name] = @handlebars.compile "{{> #{name}}}"
    @handlebars.registerPartial(name, template)

  addDecorator: (name, decorator) ->
    @handlebars.registerDecorator(name, decorator)

  addHelper: (name, helper) ->
    @handlebars.registerHelper(name, helper)

  # Private: initialize data
  #
  # override this method to do some initializations, if you inherit from
  # StorageEditor.
  initialize: ->

  # Public: override this for editing content
  #
  # This method will be called from an editor passed to {ConfluenceAPI::editPage}.
  # You can change content or title.
  #
  # * `page` {Object}
  #   * `body.storage` {String} storage representation
  #   * `spaceKey` {String} Space key of page to edit
  #   * `title` {String} Title of page to edit
  # * `options` {Object} - optional can be ignored if overridden.  The original
  #   edit may have have a field `edit`, which contains an array of following
  #   {Object}:
  #
  #   * `templates` - a list of template data:
  #     * `name` - name of thing
  #     * `type` - one of `template`, `partial`, `decorator`, `helper`
  #     * `data` - data corresponding to type
  #
  #     Partials can also be used as templates.
  #   * `template` - name of template to be applied to accompanied `data` to
  #     set `content` of this action
  #   * `data`  - passed to template
  #   * `select` - CSS selector
  #   * `action` - Action to be run on selector
  #   * `content` - content to be passed to action
  #
  #   This will result in following jQuery call:
  #
  #   ```coffee
  #   $(select)[action](content)
  #   ```
  #
  # Example:
  #
  # ```coffee
  #   editor.edit content,
  #       select: 'p:last'
  #       action: 'after'
  #       content: "<p>Hello world</p>"
  # ```
  #
  # ```coffee
  #   editor.edit content,
  #       select: 'p:last'
  #       action: 'after'
  #       templates:
  #          name: 'list'
  #          data: '''
  #            <ul>
  #            {#each items}
  #              <li>{{item}}</li>
  #            {/each}
  #            </ul>
  #          '''
  #       template: 'list'
  #       data:
  #         items: [ {item: 1}, {item: 2}, {item: 3} ]
  # ```
  #
  # If you override this method, basic skeleton is:
  #
  # ```coffee
  # class MyEditor extends StorageEditor
  #   edit: (content, options) ->
  #    $ = @beginEdit content
  #    # namespace aware CSS selector
  #    $("ac|structured-macro").replaceWith(...)
  #    # manipulate content here using n
  #    @endEdit()
  #
  # Usually
  #
  # Returns modified input {Object} or {Promise}, which resolves to it.  New
  # content shall be stored to `newBody`
  edit: (page, editor) ->
    if editor
      if editor.edit
        $=@beginEdit(page.body.storage.value)
        if editor.edit instanceof Array
          editActions = editor.edit
        else
          editActions = [ editor.edit ]

        for editAction in editActions
          if typeof editAction is 'function'
            editAction($,@)
          else
            {select, action, content, template, templates, data} = editAction

            if templates
              unless templates instanceof Array
                templates = [ templates ]
              for {name, type, data} in templates
                @['add'+type.replace(/^\w/, (m)->m.toUpperCase())](name, data)

            if template
              content = @applyTemplate(template, data)

            if select and action and content
              $(select)[action](content)

        page.newBody = @endEdit()

    else
      page.newBody = page.body.storage

    return page



  # Public: prepare content for editing
  #
  # This translates xml namespace prefixes for ns:element to ns--element, such
  # that it is selectable by CSS selectors.
  #
  beginEdit: (content) ->
    if content
      @$ = cheerio.load(content, xmlMode: true)

    @transformNamespaces ":", "--"

    jQueryWrapper = (args...) =>
      #console.log "jQueryWrapper", "this", this, "args", args, "jQuery", @$

      if isHtml args[0]
        data = @$(args[0])
        @transformNamespaces ":", "--", data.find('*')
        data
      else
        @$ args...

  # Public: end editing and return the edited HTML content
  endEdit: ->
    @transformNamespaces "--", ":"
    @$.html()

  # Private: transforms namespaces
  transformNamespaces: (src,dst,elements) ->
    if not elements
      elements = @$('*')

    transformNamespaces src, dst, elements

module.exports = StorageEditor
