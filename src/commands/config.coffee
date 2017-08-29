YAML = require 'js-yaml'
fs   = require 'fs'
path = require 'path'
os   = require 'os'

ConfigManager = require "../config-manager"

module.exports =
  command: 'config [-b baseUrl] [-u username] [-p password]'
  desc: '''
    Configure confluence CLI. You may leave out username and password.
    Then it is tried to read it from you ~/.netrc file see netrc(5).
  '''
  builder: (yargs) ->
    yargs
    .option 'baseUrl',
      alias: 'b'
      describe: "Configure Base URL"
      demandOption: false
      default: null
    .option 'username',
      alias: 'u'
      describe: "Configure username"
      demandOption: false
      default: null
    .option 'password',
      alias: 'p'
      describe: "Configure password"
      demandOption: false
      default: null

  handler: (argv) ->
    name = argv.config or 'default'
    {url, username, password} = argv

    (new ConfigManager).set name, {url, username, password}
