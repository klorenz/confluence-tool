require('coffee-script/register')
extend = require('util')._extend

_exports = {}
_exports = extend(_exports, require('./src/confluence-api'))
_exports = extend(_exports, require('./src/util'))

module.exports = _exports
