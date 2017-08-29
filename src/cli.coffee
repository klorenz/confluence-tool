fs = require 'fs'

extensions = ['coffee']
if __filename.endsWith('cli.js')
    extensions = ['js']

yargs = require('yargs')
  .usage '$ [global-options] command [options]'
  .option 'config',
      alias: 'c'
      demandCommand: false
      help: "configuration name, if you have multiple configurations"
      default: 'default'
  .commandDir './commands', extensions: extensions
  .demandCommand()
  .help()
  .argv
