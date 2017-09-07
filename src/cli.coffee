#!/usr/bin/env coffee
#fs = require 'fs'

extensions = ['coffee']
if __filename.endsWith('cli.js')
    extensions = ['js']

require('yargs')
  .usage '$0 [global-options] command [options]'
  .option 'config',
    alias: 'c'
    demandCommand: false
    help: "configuration name, if you have multiple configurations"
    default: 'default'
  .option 'debug',
    help: "write full stacktrace on error"
    type: 'boolean'
  .commandDir "#{__dirname}/commands", extensions: extensions
  .demandCommand()
  .help()
  .argv
