cheerio = require 'cheerio'

# this is from cheerio utils
quickExpr = /^(?:[^#<]*(<[\w\W]+>)[^>]*$|#([\w\-]*)$)/;
isHtml = (s) ->
  if typeof s isnt 'string'
    return false

  if s[0] is '<' and s[s.length-1] is '>' and s.length > 3
    return true
  m = s.match quickExpr
  not not (m and m[1])  # force bool

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
for method in ['append', 'prepend', 'after', 'before', 'replaceWith', 'html']
  do (method) ->
    cheerioOrig[method] = cheerio::[method]
    cheerio::[method] = (args...) ->
      args = args.map (arg) -> fixHtml arg
      cheerioOrig[method].call this, args...

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
  # * `options` {Object}
  #   * `body.storage` {String} storage representation
  #   * `spaceKey` {String} Space key of page to edit
  #   * `title` {String} Title of page to edit
  #
  # Basic skeleton is:
  #
  # ```coffee
  # class MyEditor extends StorageEditor
  #   edit: (content) ->
  #    $ = @beginEdit content
  #    # namespace aware CSS selector
  #    $("ac|structured-macro").replaceWith(...)
  #    # manipulate content here using n
  #    @endEdit()
  #
  # Returns modified input {Object} or {Promise}, which resolves to it.  New
  # content shall be stored to `newBody`
  edit: (options) ->
    options.newBody = options.body.storage

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
