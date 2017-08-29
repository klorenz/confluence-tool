if global.atom
  # need global "loophole", for browserify
  vm = require 'vm'
  global.eval = (source) ->
    vm.runInThisContext(source)
  global.Function = require('loophole').Function

PagePropEditor = require '../src/page-prop-editor.coffee'

fs = require 'fs'
path = require 'path'

cheerio = require 'cheerio'

readFixture = (name) ->
  fs.readFileSync(path.resolve __dirname, "fixtures/#{name}").toString()

describe "Page Prop Editor", ->

  describe "Type ignorant editing", ->
    content = null
    editor = null

    editProps = (content, options) ->
      editor = new PagePropEditor options
      edited = editor.edit(content)
      editor.beginEdit()

    beforeEach ->
      content =
        spaceKey: 'SPACE'
        title: 'simple'
        body: { storage: readFixture "simple.html" }

    it "can add a property", ->
      editor = new PagePropEditor properties: {Foo: 'bar'}
      edited = editor.edit(content)

      expected = readFixture "simple-expected-1.html"

      expect(edited.newBody).toBe expected

    it "can update a property", ->
      editor = new PagePropEditor properties: {Depends: 'bar'}
      edited = editor.edit(content)
      expected = readFixture "simple-expected-2.html"
      expect(edited.newBody).toBe expected

    it "can add a user", ->
      $=editProps content, properties: {Foo: {type: 'user', value: 'mickeyuserkey'}}
      expect($('tr th:contains(Foo) + td').find('ri|user').attr('ri:userkey')).toBe 'mickeyuserkey'

    it "can add a userlist", ->
      $=editProps content, properties: {Foo: {type: 'user', add: ['akey', 'bkey']}}
      expect($('tr th:contains(Foo) + td').find('ri|user').map((i,elem) -> $(elem).attr('ri:userkey')).get()).toEqual ['akey', 'bkey']

    it "can add a userlist and modify it", ->
      newContent = editor.endEdit()
      $=editProps newContent, properties: {Foo: {type: 'user', add: ['ckey', 'dkey'], remove: ['bkey']}}
      expect($('tr th:contains(Foo) + td').find('ri|user').map((i,elem) -> $(elem).attr('ri:userkey')).get()).toEqual ['akey', 'ckey', 'dkey']


    # it "can insert a property", ->
    #   editor = getPagePropEditor {Foo: {content: 'bar', after: 'Depends'}}
    #   edited = editor(content)
    #   console.log edited
    #   expected = readFixture "simple-expected-1.html"
    #
    #   expect(edited).toBe expected


      #expect(edited).toBe expected
