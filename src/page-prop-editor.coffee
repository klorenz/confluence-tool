StorageEditor = require "./storage-editor.coffee"

fs = require 'fs'

class PagePropEditor extends StorageEditor
  constructor: (@options) ->
    super

  addPartials: (names...) ->
    for name in names
      fileName = "#{__dirname}/templates/#{name}.handlebars"
      @addPartial name, fs.readFileSync(fileName).toString()

  initialize: ->
    @addPartials 'user', 'page', 'link', 'comma-list', 'list'

    if @options.templates
      for key, data of @options.templates
        @addTemplate key, data

    if @options.partials
      for key, data of @options.partials
        @addPartial key, data

    if @options.helpers
      for key, data of @options.helpers
        @addHelper key, data

#    # resolve a varname
#    @addHelper "resolve", (varname, options) ->
#      @[varname]

    if @options.decorators
      for key, data of @options.decorators
        @addDecorator key, data

  getList: ($, elem, data, selector, getItem)->
    list = []

    if data.replace
      for item in data.replace
        if item not in list
          list.push item

    else
      # find list items
      $(elem).find(selector).each (i,elem) =>
        #userkey = $(this).attr('ri:userkey')
        item = getItem elem
        if item not in list
          list.push item

    if data.add
      for item in data.add
        if item not in list
          list.push item

    if data.remove
      for item in data.remove
        if item in list
          list.remove(item)

    list.sort()
    list

    #@applyTemplate data.template or 'user-comma-list', {list}

  applyTmpl: ($elem, data, opts) =>
    if data.value
      return @applyTemplate data.template or data.type, opts

    if data.template
      template = data.template
    else
      if $elem.find('ul')
        template = "list"
      else
        template = "comma-list"

    @applyTemplate template, opts

  getRenderedProp: ($, elem, prop) ->
    # simple data
    if typeof prop is 'string'
      return prop

    # structured data
    switch prop.type
#      when 'list'

      when 'user'
        if prop.value
          data = userkey: prop.value
        else
          data = @getList $, elem, prop, 'ri|user', (x) -> $(x).attr('ri:userkey')
          data = type: 'user', list: data.map (e) -> {userkey: e, type: 'user'}

        @applyTmpl $(elem), prop, data

      when 'page'
        if prop.value
          [ spacekey, title ] = prop.value.match(/([A-Z][A-Z0-9]*):(.*)/)[1..]
          data = {spacekey, title}
        else
          data = @getList $, elem, prop, 'ri|page', (x) ->
            spaceKey = $(x).attr('ri:space-key') or input.spaceKey
            spaceKey + ":" + $(x).attr('re:title')
          data =
            type: 'page'
            list: data.map (e) ->
              m = e.match /([A-Z][A-Z0-9]):(.*)/
              {spacekey: m[1], title: m[2], type: 'page'}

        @applyTmpl $(elem), prop, data

      when 'link'
        if prop.value
          data = url: prop.value
        else
          data = @getList $, elem, prop, 'a', (x) -> $(x).attr('href')
          data = type: 'link', list: data.map (e) -> url: e, type: 'link'
        @applyTmpl $(this), data, data

      else
        if prop.template
          html = @applyTemplate prop.template, value: prop.value
        else
          html = prop.value

        html

  edit: (input) ->
    updated = []

    $=@beginEdit input.body.storage.value

    $("ac|structured-macro[ac|name=details] table tr").each (i, elem) =>
      # for whatever reason this != elem !!! I do not understand this
      # this is PagePropEditor instead of the elem
      #debugger
      #console.log "args", args, "this", this, "$", $
      key = $(elem).find('th').text()
      props = @options.properties
      return unless key of props

      updated.push key

      $(elem).find('td').html @getRenderedProp $, elem, props[key]

    #console.log "updaed", updated

    dummy = $("<div></div>")
    for key,prop of @options.properties
      if key not in updated
        rendered = @getRenderedProp $, dummy, prop
        tr = "<tr><th>#{key}</th><td>#{rendered}</td></tr>"
        $("ac|structured-macro[ac|name=details] table tbody").append tr

    input.newBody = @endEdit()
    input

module.exports = PagePropEditor
