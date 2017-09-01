require '../src/promise-patch'

describe "Promise Patch", ->
  describe "Promise patch iterate", ->
    it "can run functions sequentially", ->

      waitsForPromise ->
        Promise.iterate [(-> 42), (-> Promise.resolve(43))]
        .then (values) ->
          expect(values).toEqual [42, 43]

  describe "Promise patch parallel", ->
    it "can run functions in parallel", ->
      waitsForPromise ->
        promise = Promise.parallel([
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(1)), 100)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(2)), 50)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(3)), 25)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(4)), 75)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(5)), 120)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(6)), 10)
            -> new Promise (resolve, reject) -> setTimeout((-> resolve(7)), 80)
          ], 3, (value) -> console.log "promise returned", value
        ).then (values) ->
          expect(values).toEqual [1,2,3,4,5,6,7]
