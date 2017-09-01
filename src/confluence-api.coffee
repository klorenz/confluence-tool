request = require 'request'
extend  = require('util')._extend
StorageEditor = require './storage-editor'
PagePropEditor = require './page-prop-editor'
{jQuery} = StorageEditor

{isHtml, promised} = require './util'
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
        else
          debugger
          try
            body = JSON.parse body

            if body.statusCode? and body.statusCode >= 400
              err = new Error "#{body.statusCode}: #{body.message}"
              err.data = body
              reject err
            else
              resolve body
          catch e
            err = new Error "#{response.statusCode}: #{response.statusMessage}"
            err.response = response
            reject err

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
  # * `ref` - resolve to a valid CQL
  #   * `SPACE:page title` ->  `space = SPACE AND title = "page title"`
  #   * `:page title` -> `title = "page title"`
  #   * `1234567` -> `ID = 1234567`
  #   * ends with `api/content/12345` -> `ID = 12345`
  #   * else assume `ref` is already CQL
  #
  resolveCQL: (ref) ->
    if typeof ref isnt "string"
      ref = ref.toString()

    if mob = ref.match /^([A-Z]*):(.*)/
      value = "space = #{mob[1]} AND title = \"#{mob[2]}\""

    else if mob = ref.match /^:(.*)/
      value = "title = \"#{mob[2]}\""

    else if mob = ref.match /^(\d+)$/
      value = "ID = #{mob[1]}"

    else if mob = ref.match /api\/content\/(\d+)$/
      value = "ID = #{mob[1]}"

    else
      value = ref

    #console.log "value", value

    return value

  # Section: Pages

  # get a page
  #
  # * `page_ref` may be either a page ID or a URL as returned from
  #   confluence REST API
  getPage: (page_ref, expand='') ->
    new Promise (resolve, reject) =>
      #console.log "page_ref", page_ref
      @search @resolveCQL(page_ref), {expand}
      .then (result) =>
        #console.log "result", result

        if result['size'] > 1
          reject new Error "ambigious query returned more than one page"

        if result['size'] == 0
          reject new Error "page does not exist"

        resolve result['results'][0]
      .catch(reject)


  # find pages
  #
  # - `query` must be a CQL
  search: (query, options) ->
    #console.log "search", query
    @get "/rest/api/content/search", qs: (extend {cql: query}, options)

  eachPage: (query, options, callback) ->
    #console.log "each page", query, options
    if options instanceof Function
      callback = options
      options = {}

    new Promise (resolve, reject) =>
      getPages = (opts) =>
        @search(query, opts)
        .then (data) =>
          #console.log "search data", query, opts
          #console.log "results", data

          promises = []

          for page in data['results']
            page.spaceKey = page._expandable.space.match(/\/([^\/]*)$/)[1]
            #console.log "handle", page
            if callback
              promises.push promised callback page

          Promise.all promises
          .then ->
            if data['size'] < data['limit']
              resolve()
            else
              _opts = extend {}, opts
              _opts.start += _opts.limit

              getPages(_opts)
          .catch(reject)
        .catch(reject)

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


  getPageProperties: (cql, options, callback) ->
    if not callback and options instanceof Function
      callback = options
      options = {}

    bodyType  = options.bodyType ? "view"
    stripTags = options.stripTags ? true

    @eachPage cql, {expand: "body.#{bodyType}"}, (page) =>
      page.properties = props = {}
      $=jQuery(page.body.view.value)

      didCallback = []

      $("div[data-macro-name=details] table > tbody th").each (i,elem) =>
        key = $(elem).text().trim()

        if stripTags
          extractData = ($e) =>
            $x = $e.find('li, table th + td')

            if $x.length
              if $x.get(0).tagName is 'li'
                value = $e.find('li').map((i,e) -> extractData $(e)).get()
              else
                value = {}
                $e.find('table th').each (i,e) =>
                  value[$(e).text().trim()] = extractData $(e).next()
            else
              value = $e.text().trim()

            return value

          value = extractData $(elem).next()
        else
          value = $(elem).next().html()

        props[key] = value

      if callback
        didCallback.push promised callback props, page

      Promise.all didCallback



  # Section: Page Properties
  getPageProperties2: (cql, options, callback) ->
    if not callback and options instanceof Function
      callback = options
      options = {}

    # setup set of heading (property keys) to retrieve
    keys = options.keys or []  # beware!  keys are case sensitive
    headingQS = {}
    if keys.length
      headingQS['headings'] = keys.join(',')

    # property (masterdetail) queries must be done per space, so first find out
    # about all pages and the spaces they are in
    pagesPerSpace = {}
    new Promise (resolve, reject) =>

      # first collect pages using CQL to find out about the spaces
      @eachPage cql, (page) ->
        #console.log "pageid", page.id
        if not pagesPerSpace[page.spaceKey]
          pagesPerSpace[page.spaceKey] = []

        pagesPerSpace[page.spaceKey].push page.id

      .then =>
        # collect all space
        gotSpaceSet = []

        for spaceKey, pageIds of pagesPerSpace
          do (spaceKey) =>
            # devide pageId list into chunks of 25.  Looks like there is some
            # limit in retrieving data
            chunks = []
            for i in [0...pageIds.length] by 25
              chunks.push pageIds[i...(i+25)]

            # retrieve chunk one by one
            gotSpaceSet.push Promise.iterate chunks.map (chunk) =>
              cql = "ID in (#{chunk.join(", ")})"
              qs = extend {spaceKey, cql}, headingQS

              @get "/rest/masterdetail/1.0/detailssummary/lines", {qs}
              .then (result) =>
                new Promise (resolve, reject) =>
                  headings = result['renderedHeadings']
                  didCallback = []

                  # if result.asyncRenderSafe is false
                  #   # OMG! get data in a different way, mimic masterdetail result
                  #   result = {cql, spaceKey}
                  #
                  #   detailLines = []
                  #   Promise.iterate chunks.map (pageId) =>
                  #     @getPage pageId, 'body.view' (result) =>
                  #       $=jQuery(result.body.view)
                  #       details = []
                  #       for heading in headings
                  #         elems = $("div[data-macro-name=details] table > tbody th:contains(#{heading}) + td")
                  #         if elems.length
                  #           details.push elems[0]
                  #         else
                  #           details.push ''
                  #
                  #       detailLines.push {
                  #         id: result.id
                  #         title: result.title
                  #         relativeLink: result._links.webui
                  #         details: details
                  #         # likesCount
                  #         # commentsCount
                  #       }
                  #
                  #     if callback
                  #       didCallback.push promised callback props, rec
                  #   .then
                  #
                  #   #@eachPage chunk
                  #
                  # else
                  result.cql = cql
                  result.spaceKey = spaceKey

                  for rec in result['detailLines']

                    rec['properties'] = props = {}

                    rec.spaceKey = spaceKey

                    # zip properties into array
                    for i in [0...headings.length]
                      props[headings[i]] = rec.details[i]

                    if callback
                      didCallback.push promised callback props, rec

                  # make sure all callbacks are finished, bifore this resolves
                  Promise.all didCallback
                  .then ->
                    resolve result
                  .catch(reject)

              .catch(reject)

        Promise.all gotSpaceSet
        .then (results) ->
          #console.log "results", results
          result =
            currentPage: 0
            totalPages: 0
            renderedHeadings: results[0].renderedHeadings
            detailLines: []
            asyncRenderSafe: true

          for value in results
            #console.log "value", results
            continue unless value.detailLines
            for detail in value.detailLines
              result.detailLines.push detail

          resolve result
        .catch(reject)
      .catch(reject)


  updatePage: (page) ->
    {id, title} = page

    #updateRequest = extend {}, page
    if page.version
      if page.version.number
        version = number: parseInt(page.version.number) + 1
      else
        version = number: parseInt(page.version) + 1

    # page.spaceKey is undefined here
    #console.log "spaceKey", page.spaceKey
    #space = page.space.key

    representation = null
    value = null

    # be generous in specifying the content
    if page.newBody
      value = page.newBody

    else if typeof page.body is 'string'
      value = page.body

    else if typeof page.body.storage is 'string'
      value = page.body.storage

    else if page.body.storage # assume data is setup correct
      {value, representation} = page.body.storage


    type = page.type or 'page'

    data = {id, title, type, version}

    if value?
      representation ?= if isHtml(value) then 'storage' else 'wiki'
      data.body = storage: {value, representation}

    #console.log "updatePage", data

    @put "/rest/api/content/#{id}", json: data

  # Public: edito a page
  #
  # * `page` page to edit, may be a page object as returned from confluence or
  #   "SPACE:Title", or 123456 (page id) or a CQL resolving to one page. Although
  #   named page here, it may be also a 'blog' post.  Any spec will be resolved
  #   to page object, which then is passed to page editor if any.
  #
  # * `editor` - can be one of the following
  #
  #   - {Object} having a method `edit`, or a {Function} which gets page object
  #     as parameter.  It can resolve to one of the following items.
  #   - {Promise} to get one of the following items.
  #   - {String} new content of page
  #   - {Object} updating given page object, so usually it should have
  #     - new `title` to rename page
  #     - `newBody` to update the body
  #   - page {Object} as returned from confluence REST having maybe `newBody`
  #     as new body.  If not present, then usual `body` field will be interpreted
  #     as new body.
  #
  #  `representation` of the body will be guessed.  If is HTML, then it will
  #  be `storage`, else `wiki`.
  #
  editPage: (page, editor) ->
    #console.log "page", page
    new Promise (resolve, reject) =>
      if typeof page is 'object' and page.version and page.body
        gotPage = Promise.resolve(page)
      else
        gotPage = @getPage page, 'version,body.storage'

      gotPage
      .then (page) =>
        #console.log "got page", page
        value = null

        if editor.edit
          if typeof editor.edit is 'function'
            value = editor.edit page
          else
            myEditor = new StorageEditor
            value = myEditor.edit page, editor.edit

        else if typeof editor is 'function'
          value = editor page
        else
          value = editor

        if not (value instanceof Promise)
          edited = Promise.resolve(value)

        edited
        .then (value) =>
          if typeof value is 'string'
            updatedPage = extend page {newBody: editor}
          else if typeof editor is 'object'
            updatedPage = extend page, value

          @updatePage updatedPage
          .then(resolve).catch (error) ->
             #console.log(error)
             reject(error)
      .catch(reject)

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

    #console.log "options", options

    Promise.iterate options.map (option) =>
      new Promise (resolve, reject) =>
        @preparePageProperties(option.properties)
        .then =>
          if option.cql and option.page
            thow new Error "You may only pass either 'cql' or 'page'"

          #console.log "apply", option

          pagePropEditor = new PagePropEditor option

          cql = option.cql or @resolveCQL option.page
          @eachPage cql, {expand: 'version,body.storage'}, (page) =>
            #console.log "handle page", page.id

            new Promise (resolve, reject) =>
              @editPage page.id, pagePropEditor
              .then (value) ->
                if callback
                  callback value
                resolve value
              .catch(reject)
          .then(resolve)
          .catch(reject)

        .catch(reject)



module.exports = {ConfluenceAPI, StorageEditor}
