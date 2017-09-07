require('coffee-script/register')
var extend = require('util')._extend
var _exports = {}

_exports = extend(_exports, require('./src/confluence-api'))
_exports = extend(_exports, require('./src/util'))
_exports.ConfigManager = require('./src/config-manager')

module.exports = _exports
