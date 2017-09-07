{promised} = require "./util"

# http://promise-nuggets.github.io/articles/15-map-in-series.html
Promise.iterate = (funcs, callback) ->
  # start with current being an "empty" already-fulfilled promise
  current = Promise.resolve();

  Promise.all funcs.map (func) ->
    current = current.then (value) ->
      new Promise (resolve, reject) ->
        promised func
        .then (value) ->
          if callback
            promised callback value
            .then resolve
            .catch reject
          else
            resolve value
        .catch reject

        # if callback
        #   callback value

# http://promise-nuggets.github.io/articles/16-map-limit.html
Promise.parallel_experimental = (funcs, slots, callback) ->
  if slots instanceof Function
    callback = slots
    slots = funcs.length

  index = 0
  promises = (Promise.resolve() for item in [0...slots])
  values = []

  next = ->
    return unless index < funcs.length
    index += 1
    func = funcs[index]
    console.log "run func #{index}"

    new Promise (resolve, reject) ->
      promised func()
      .then (value) ->
        callback value if callback
        values[index] = value

        if index < funcs.length
          next().then(resolve).catch(reject)
        else
          resolve()
      .catch reject


  promises.map (promise, i) ->
    promise[i] = promise[i].then(next).catch(reject)

  new Promise (resolve, reject) ->
    Promise.all promises.map (promise, i) ->
      promise[i] = promise[i].then(next).catch(reject)
    .then ->
      resolve values
    .catch reject
