fs = require 'fs'
StorageEditor = require '../src/storage-editor.coffee'

describe "Storage Editor", ->
  content = ''
  beforeEach ->
    content = fs.readFileSync("#{__dirname}/fixtures/simple.html").toString()

  it "can handle namespace selections", ->
    editor = new StorageEditor
    $=editor.beginEdit(content)
    expect($('ac|structured-macro').length).toBe 2

  it "can append namespaced data", ->
    editor = new StorageEditor
    $=editor.beginEdit("<ab:foo>x</ab:foo>")
    debugger
    $('*').append("<x:y/>")
    expect($('x|y').length).toBe 1
    expect(editor.endEdit()).toBe "<ab:foo>x<x:y/></ab:foo>"

  it "can prepend namespaced data", ->
    editor = new StorageEditor
    $=editor.beginEdit("<ab:foo>x</ab:foo>")
    debugger
    $('ab|foo').prepend("<x:y/>")
    expect($('x|y').length).toBe 1
    expect(editor.endEdit()).toBe "<ab:foo><x:y/>x</ab:foo>"
