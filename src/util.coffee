# this is from cheerio utils
quickExpr = /^(?:[^#<]*(<[\w\W]+>)[^>]*$|#([\w\-]*)$)/;
isHtml = (s) ->
  if typeof s isnt 'string'
    return false

  if s[0] is '<' and s[s.length-1] is '>' and s.length > 3
    return true
  m = s.match quickExpr
  not not (m and m[1])  # force bool

# turn value into promise in case it isnt one
promised = (value) ->
  if value instanceof Function
    value = value()
  if value not instanceof Promise
    Promise.resolve(value)
  else
    value

didReadStdin = new Promise (resolve, reject) ->
  input = ''
  process.stdin.resume()
  process.stdin.on 'data', (buf) -> input += buf.toString()
  process.stdin.on 'error', (error) ->
    reject error
  process.stdin.on 'end', ->
    resolve input

module.exports = {didReadStdin, isHtml, promised}
