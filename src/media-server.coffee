express = require('express')
async = require('async')
program = require('commander')
partial = require('partial')
media_parser = require('media-parser')

app = express()


# --- Parse
app.get('/parse', (req, res) ->
    # Setup query arguments
    timeout = parseInt(req.query.timeout or 5) * 1000
    urls = req.query.urls or "[]"
    min_tn_size = parseInt(req.query.min_tn_size or 100)
    callback = req.query.callback or null

    try
        urls = JSON.parse(urls)
    catch e
        return res.send(500, 'Invalid JSON encoding of urls')

    # Process the requests in parallel
    cb_functions = []
    for _url in urls
        cb = (url, async_cb) ->
            media_parser.parse(url, (obj) ->
                if obj
                    if obj.get_thumbnail_url
                        thumb_info = obj.get_thumbnail_url(min_tn_size)
                        delete obj.get_thumbnail_url
                        if thumb_info
                            obj.thumbnail_url = thumb_info[0]
                            obj.thumbnail_width = thumb_info[1]
                            obj.thumbnail_height = thumb_info[2]

                    result = obj
                else
                    result = {'error': 'Could not resolve resource'}
                async_cb(null, [url, result])
            , timeout)
        cb_functions.push(partial(cb, _url))

    async.parallel(cb_functions, (err, cb_results) ->
        results = {}
        for rpair in cb_results
            results[rpair[0]] = rpair[1]

        json = JSON.stringify(results)

        if callback
            res.set({'Content-Type': 'text/javascript'})
            res.send(callback + "(" + json + ")")
        else
            res.set({'Content-Type': 'application/json'})
            res.send(json)
    )
)


# --- Command line setup
usage = "A specialized API for handling oemebed requests"

program
  .version('0.0.1')
  .usage(usage)
  .option('-p, --port <port>')
  .parse(process.argv)

program.port = parseInt(program.port or '8080')

media_parser.MediaParser.init(media_parser.NodeHttpService)

app.listen(program.port)

console.log('Started Media Server on ' + program.port)
