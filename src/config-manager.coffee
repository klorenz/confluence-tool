{ConfluenceAPI} = require 'atlassian-confluence-api'
os = require 'os'
fs = require 'fs'
YAML = require 'js-yaml'


module.exports =
class ConfigManager
  constructor: ->
    @configFile = os.homedir() + "/.atlassian-confluence-cli"

  # get config file name and assert that it exists and is only user accessible
  getConfigFile: ->
    # make sure mode is only user-accessible
    if not fs.existsSync @configFile
      fs.writeFileSync @configFile, ''

    fs.chmod @configFile, '0600'

    @configFile

  getConfluenceAPI: (name) ->
    new ConfluenceAPI @get name

  # get named configuration or default configuratino
  get: (name) ->
    @readConfig()[name or 'default']

  # set named configuration
  set: (name, config) ->
    @writeConfig name, config

  # read configuration file
  readConfig: ->
    YAML.safeLoad fs.readFileSync @getConfigFile()

  # write named configuration
  writeConfig: (name, config) ->
    fs.writeFileSync @getConfigFile(), YAML.safeDump default: config
