request = require 'request'
extend  = require('util')._extend
StorageEditor = require './storage-editor'
PagePropEditor = require './page-prop-editor'
require './promise-patch'


class ConfluenceAPI
  constructor: ({@url, @username, @password, @version}) ->
    {protocol, auth, host, path} = require('url').parse(@url)
    @url = "#{protocol}//#{host}#{path}"

    if not @url.match /\/$/
      @url += "/"

    if not @username?

      if auth?
        [ @username, @password ] = auth.match(/^(.*?):(.*)/)[1..]

      if not @username?
        account = require('netrc')()[host]
        @username = account.login
        @password = account.password

    # hold the session in a jar
    @jar = request.jar()

  request: (method, path, options) ->
    #console.log "request", method, path, options

    opts = extend {}, options or {}
    opts.jar = @jar
    if path.match /^\//
      path = path[1..]
    opts.url = "#{@url}#{path}"
    # opts.headers ?= {}
    # opts.headers['X-Atlassian-Token'] = 'no-check'
    opts.auth = {user: @username, pass: @password, sendImmediately: true}
    #opts.accept = "*/*"

    new Promise (resolve, reject) =>
      request[method] opts, (error, response, body) =>
        if error
          reject error
        else if response.statusCode >= 400
          err = new Error "#{response.statusCode}: #{response.statusMessage}"
          err.response = response
          reject err
        else
          if typeof body is "string"
            #console.log "turnted to JSON"
            body = JSON.parse body
          else
            #console.log "isnt string"

          if body.statusCode? >= 400
            err = new Error "#{json.statusCode}: #{json.message}"
            err.data = body
            reject err
          else
            #console.log "body type", body.constructor
            resolve body

  get: (path, options) ->
    @request 'get', path, options

  post: (path, options) ->
    @request 'post', path, options

  put: (path, options) ->
    @request 'put', path, options

  delete: (path, options) ->
    @request 'delete', path, options

  # create a space
  #
  # - `opts` -- {Object}
  #
  #   See Confluence REST browser for keys.
  #
  # Example:
  #
  #   confluence.createSpace {key: "KEY", name: "Space Name"}
  #
  createSpace: (options) ->
    {description, key, name, type} = options

    type ?= 'global'

    if typeof description is "string"
      description =
        plain:
          value: description
          representation: 'plain'

    params = extend extend({}, options), {key, name, type, description}

    @post('/rest/api/space', json=params)

  # Section: Spaces

  getSpace: (options) ->
    {spaceKey, expand} = options
    @get '/rest/api/space/#{spaceKey}', qs: {expand}

  eachSpace: (options, callback) ->
    params = extend {limit: 100, start: 0}, options

    new Promise (resolve, reject) =>
      getSpaces = (params) =>
        @get('/rest/api/spaces', qs: params).then (data) =>
          for space in data['results']
            callback(space)

          if data['size'] < data['limit']
            resolve()
          else
            _params = extend {}, params
            _params.start += _params.limit
            getSpaces(_params)

        .catch (error) =>
          reject(error)

      getSpaces(params)

  getSpaceHomePage: (spaceKey) ->
    new Promise (resolve, reject) =>
      @getSpace(spaceKey, expand: 'homepage').then (data) =>
        resolve data['homepage']['id']
      .catch (error) ->
        reject error

  # resolve some string variants to CQL queries
  #
  # - `ref` - 'SPACE:page title', '<page ID>'
  resolveCQL: (ref) ->
    if typeof ref isnt "string"
      ref = ref.toString()

    if mob = ref.match /^([A-Z]*):(.*)/
      return "space = #{mob[1]} AND title = \"#{mob[2]}\""

    if mob = ref.match /^(\d+)$/
      return "ID = #{mob[1]}"

    if mob = ref.match /api\/content\/(\d+)$/
      return "ID = #{mob[1]}"

    return ref

  # Section: Pages

  # get a page
  #
  # * `page_ref` may be either a page ID or a URL as returned from
  #   confluence REST API
  getPage: (page_ref, expand='') ->
    new Promise (resolve, reject) =>
      @search @resolveCQL(page_ref), {expand}
      .then (result) =>
        if result['size'] > 1
          reject new Error "ambigious query returned more than one page"

        if result['size'] == 0
          reject new Error "page does not exist"

        resolve result['results'][0]
      .catch (error) =>
        reject error


  # find pages
  #
  # - `query` must be a CQL
  search: (query, options) ->
    @get "/rest/api/content/search", qs: (extend {cql: query}, options)

  eachPage: (query, options, callback) ->
    if options instanceof Function
      callback = options
      options = {}

    new Promise (resolve, reject) =>
      getPages = (opts) =>
        @search(query, opts).then (data) =>
          #console.log "search data", data.constructor, data

          #console.log "results", data.results
          for page in data['results']
            page.spaceKey = page._expandable.space.match(/\/([^\/]*)$/)[1]
            #console.log "handle", page
            if callback
              callback(page)

          if data['size'] < data['limit']
            resolve()
          else
            _opts = extend {}, opts
            _opts.start += _opts.limit

            getPages(_opts)

        .catch (error) =>
          reject(error)

      getPages extend {start: 0, limit: 25}, options

  addLabels: (query, labels, callback) ->
    labelData = for label in labels
      if mob = label.match /(.*):(.*)/
        prefix: mob[1], name: mob[2]
      else
        prefix: 'global', name: label

    errors = []
    succeeded = []

    new Promise (resolve, reject) =>
      @eachPage(query, (page) =>
        @post("/rest/api/content/#{page.id}/label", json: labelData)
        .then (data) =>
          if data.statusCode
            errors.push { page, data }
          else
            succeeded.push { page, data }

          if callback
            callback page, data

        .catch (error) =>
          errors.push { page, error }
      )
      .then =>
        if errors.length
          reject({errors, succeeded})
        else
          resolve(succeeded)
      .catch (error) =>
        reject({error, errors, succeeded})

  # Section: Page Properties
  getPageProperties: (cql, options, callback) ->
    if not callback and options instanceof Function
      callback = options
      options = {}

    pagesPerSpace = {}

    new Promise (resolve, reject) =>
      @eachPage cql, (page) ->
        if not pagesPerSpace[page.spaceKey]
          pagesPerSpace[page.spaceKey] = []

        pagesPerSpace[page.spaceKey].push page.id

      .then =>
        keys = options.keys or []  # beware!  keys are case sensitive

        headingQS = {}
        if keys.length
          headingQS['headings'] = keys.join(',')

        promises = []

        for spaceKey, pageIds of pagesPerSpace
          do (spaceKey) =>
            cql = "ID in (#{pageIds.join(", ")})"

            qs = extend {spaceKey, cql}, headingQS
            #console.log "qs", qs

            promises.push( @get "/rest/masterdetail/1.0/detailssummary/lines", {qs}
            .then (result) =>
              headings = result['renderedHeadings']
              #console.log "result", result

              for rec in result['detailLines']

                #console.log "rec", rec
                rec['properties'] = props = {}

                rec.spaceKey = spaceKey

                # zip properties into array
                for i in [0...headings.length]
                  props[headings[i]] = rec.details[i]

                if callback
                  callback props, rec

              result
            .catch (error) ->
              console.log error
              reject error

            )

        Promise.all promises
        .then (values) ->
          result =
            currentPage: 0
            totalPages: 0
            renderedHeadings: values[0].renderedHeadings
            detailLines: []
            asyncRenderSafe: true

          for value in values
            for detail in value.detailLines
              result.detailLines.push detail

          resolve result
        .catch (error) ->
          reject error

  updatePage: (page) ->
    {id, title} = page

    #updateRequest = extend {}, page
    if page.version
      if page.version.number
        version = number: parseInt(page.version.number) + 1
      else
        version = number: parseInt(page.version) + 1

    console.log "spaceKey", page.spaceKey
    #space = page.space.key

    if page.newBody
      body =
        storage:
          value: page.newBody
          representation: 'storage'

    else if typeof page.body is 'string'
      body =
        storage:
          value: page.body
          representation: 'storage'

    type = 'page'
    data = {id, title, type, version, body}
    #console.log "updatePage", data

    @put "/rest/api/content/#{id}", json: data


  # Public: edito a page
  #
  # - `page` page to edit
  # - `editor` must have an edit method or must be a function.  Edit method or
  #   function is called with content as parameter and must return either the
  #   new content or a promise resolving to the new content.
  #
  editPage: (page, editor) ->
    new Promise (resolve, reject) =>
      if typeof page is 'object' and page.version and page.body
        promise = Promise.resolve(page)
      else
        promise = @getPage page, 'version,body.storage'

      promise
      .then (page) =>

        if editor.edit
          edited = editor.edit page
        else
          edited = editor page

        if not (edited instanceof Promise)
          edited = Promise.resolve(edited)

        edited
        .then (page) =>
          @updatePage page
          .then(resolve).catch (error) ->
             console.log(error)
             reject(error)

  # promise to resolve the query for a user
  #
  # Either:
  # - `username` - {Object} with
  #   - `key` beeing the userKey or `username`
  #   - `expand` values to expand
  #
  # Or:
  # - `username` {String} username
  # - `expand` {String} values to expand
  #
  # Please note, that `expand` is part of the API, but there is nothing to expand
  # for now.
  #
  # Example:
  #
  # ```coffee
  #   confluence.getUser('name').then (userdata) ->
  #      # do something with userdata
  # ```
  getUser: (username, expand='') ->
    if typeof username is 'string'
      qs = {username, expand}
    else
      qs = username

    @get "/rest/api/user", {qs}

  # Private: preparePageProperties
  #
  # - resolve user names to userkeys
  #
  preparePageProperties: (props) ->
    new Promise (resolve, reject) ->
      promises = []
      for key, prop of props
        continue if typeof prop is 'string'

        if 'value' of prop and ('add' of prop or 'remove' of prop)
          throw new Error "invalid prop data, either value or add/remove"

        if prop.type is 'user'
          if 'value' of prop
            do (prop) =>
              prop.valueOrig = prop.value
              promises.push @getUser(prop.value).then (data) ->
                prop.value = data.userKey

          for k in ['add', 'remove']
            do (prop, k) =>
              prop[k+'Orig'] = vals = prop[k]
              gotVals = for val in vals
                @getuser(val).then (data) ->
                  prop[k] = value

              promises.push Promise.all(gotVals)

#        if prop.type is ''

      Promise.all(promises).then ->
        resolve()
      .catch (error) ->
        reject(error)



  #appendPageProperties: (cql, props) ->
  #
  # Actors '{type: "user-list", add: ["kai", "ben"], remove: ["kiwi"]}'
  # Depends '{type: "ref-list", add: ["SPACE:page titile", 12345], format: "<ac:structured-macro ...><ac:parameter>"}'
  #
  # Following types are allowed:
  #   * user - resolve users to user keys (for wrapping in user link)
  #   * ref  - list of page or blog references: need SPACE:title form, wrapped with
  #   * link - list of web links
  #   * storage (default) - raw storage format
  #   * aggregate - aggregate value from some list of links.
  #
  # You can either define a `value` (to replace the value)
  # or `add` and or `remove` to manipulate a list.
  #
  # wrap parameter will be wrapped around the resulting item, OR
  # you can use format parameter with {{value}} to replace the value, {{rendered}} to
  # replace with type-dependend rendered value.
  #
  # Lists can be either comma seperated (with at most x items per row)
  # or <li>
  #




  # Public: Set page properties
  #
  # * `options`, which can be one options {Object} or an array of option objects
  #   One option object may have following keys:
  #
  #   * `page` or `cql`, which both resolve internally to a CQL, if you have
  #   * `properties` {Object} with names as keys.  Values may be either {String}
  #     or {Object}:
  #
  #     * `value` - set parameter to this value
  #     * `type`  - type of value, may be 'user', 'page', 'link',
  #     * 'template' - a template name
  #     * 'templates' -
  #     * 'partials'
  #     * TODO: continue this.
  #
  # Returns a promise, which resolves to an array of updatePage results
  setPageProperties: (options, callback) ->
    if options not instanceof Array
      options = [ options ]

    Promise.iterate options.map (option) =>
      @preparePageProperties(option.properties)
      .then =>
        pagePropEditor = new PagePropEditor options

        if option.cql and option.page
          thow new Error "You may only pass either 'cql' or 'page'"

        cql = option.cql or @resolveCQL option.page
        @eachPage cql, {expand: 'version,body.storage'}, (page) =>
          @editPage page.id, pagePropEditor
          .then (value) ->
            callback (value)



module.exports = {ConfluenceAPI, StorageEditor}
