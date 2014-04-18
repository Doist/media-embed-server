express = require('express')
async = require('async')
program = require('commander')
partial = require('partial')
media_parser = require('media-parser')
Memcached = require('memcached')

app = express()


# --- Parse
app.get('/parse', (req, res) ->
    # Setup query arguments
    timeout = parseInt(req.query.timeout or 5) * 1000
    content = req.query.content or ""
    min_tn_size = parseInt(req.query.min_tn_size or 100)
    callback = req.query.callback or null

    # Process the requests in parallel
    cb_functions = []
    for _url in media_parser.extractURLs(content)
        cb = (url, async_cb) ->
            cache_key = _url + ':' + min_tn_size

            app.cache.get(cache_key, (err, cached_data) ->
                if cached_data
                    try
                        cached_data = JSON.parse(cached_data)
                    catch e
                        cached_data = null

                if cached_data
                    async_cb(null, cached_data)
                else
                    media_parser.parse(url, (obj) ->
                        if obj
                            if obj.get_thumbnail_url
                                thumb_info = obj.get_thumbnail_url(min_tn_size)
                                delete obj.get_thumbnail_url
                                if thumb_info
                                    obj.thumbnail_url = thumb_info[0]
                                    obj.thumbnail_width = thumb_info[1]
                                    obj.thumbnail_height = thumb_info[2]

                            obj.matched_url = url
                            app.cache.set(cache_key, JSON.stringify(obj), 3600)
                            async_cb(null, obj)
                        else
                            result = {'error': 'Could not resolve resource'}
                            result.matched_url = url
                            async_cb(null, result)
                    , timeout)
            )

        cb_functions.push(partial(cb, _url))

    async.parallel(cb_functions, (err, cb_results) ->
        json = JSON.stringify(cb_results)

        if callback
            res.set({'Content-Type': 'text/javascript'})
            res.send(callback + "(" + json + ")")
        else
            res.set({'Content-Type': 'application/json'})
            res.send(json)
    )
)


# --- Providers
app.get('/providers', (req, res) ->
    res.set({'Content-Type': 'application/json'})
    res.send(media_parser.getProviders())
)


# --- Command line setup
usage = "A specialized API for handling oemebed requests"

program
  .version('0.0.1')
  .usage(usage)
  .option('-p, --port <port>')
  .option('-c, --cache <cache>')
  .parse(process.argv)

program.port = parseInt(program.port or '8080')
program.cache = program.cache or null

# --- Init
if program.cache
    app.cache = new Memcached(program.cache, {'timeout': 500, 'failures': 1})
else
    app.cache = {
        get: (key, cb) -> cb()
        set: -> null
    }

# --- Start
app.listen(program.port)
console.log('Started Media Server on ' + program.port)
