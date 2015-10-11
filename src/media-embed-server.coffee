http = require('http')
express = require('express')
async = require('async')
program = require('commander')
partial = require('partial')
media_parser = require('media-parser')
webpage_info = require('webpage-info')
imagesize = require('imagesize')
Memcached = require('memcached')

app = express()


# --- Parse
parse = (req, res) ->
    # Setup query arguments
    version = parseInt(req.query.version or 1)
    timeout = parseInt(req.query.timeout or 5) * 1000
    content = req.query.content or ""
    min_tn_size = parseInt(req.query.min_tn_size or 100)
    callback = req.query.callback or null

    # Process the requests in parallel
    cb_functions = []
    for _url in media_parser.allURLs(content)
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
                    media_parser.parse(url, (parsed_obj) ->
                        if parsed_obj
                            result = {}

                            if parsed_obj.underlying_type
                                result.type = parsed_obj.underlying_type
                            else
                                attachType(version, result, url)

                            attachTitle(version, result, parsed_obj.title, url)
                            attachUrl(version, result, url)

                            if parsed_obj.raw and parsed_obj.raw.html
                                result.html = parsed_obj.raw.html

                            if parsed_obj.content_url and parsed_obj.content_type
                                result.content_url = parsed_obj.content_url
                                result.content_type = parsed_obj.content_type

                            if parsed_obj.get_thumbnail_url
                                thumb_info = parsed_obj.get_thumbnail_url(min_tn_size)

                                if thumb_info
                                    attachThumbnail(version, result, thumb_info)

                            update_cache = true

                            handleAsyncCall(async_cb, cache_key, update_cache, result, timeout)
                        else
                            webpage_info.parse(url, (parsed_obj) ->
                                if parsed_obj.error or !parsed_obj.title
                                    result = {'error': 'Could not resolve resource'}
                                    update_cache = false
                                else
                                    result = {}

                                    update_cache = true

                                    attachType(version, result, url)

                                    attachTitle(version, result, parsed_obj.title, url)

                                    if parsed_obj.thumbnail
                                        result.thumbnail = {
                                            "url": parsed_obj.thumbnail.url
                                            "width": parsed_obj.thumbnail.width
                                            "height": parsed_obj.thumbnail.height
                                        }

                                attachUrl(version, result, url)

                                handleAsyncCall(async_cb, cache_key, update_cache, result, timeout)
                            )
                    , timeout)
            )

        cb_functions.push(partial(cb, _url))

    async.parallel(cb_functions, (err, cb_results) ->
        json = JSON.stringify(cb_results)

        if callback
            res.set({'Content-Type': 'text/javascript; charset=utf-8'})
            res.send(callback + "(" + json.toString('utf8') + ")")
        else
            res.set({'Content-Type': 'application/json; charset=utf-8'})
            res.send(json.toString('utf8'))
    )


handleAsyncCall = (async_cb, cache_key, update_cache, result, timeout) ->
    callback = ->
        if update_cache
            app.cache.set(cache_key, JSON.stringify(result), 3600*24)
        async_cb(null, result)

    # --- Clean up thumbnail info
    thumbnail = result.thumbnail

    if thumbnail and thumbnail.width
        thumbnail.width = parseInt(thumbnail.width)

    if thumbnail and thumbnail.height
        thumbnail.height = parseInt(thumbnail.height)

    if thumbnail and thumbnail.url and (!thumbnail.width or !thumbnail.height)
        turl = thumbnail.url.replace('https', 'http')
        request = http.get(turl, (response) ->
            imagesize(response, (err, image_result) ->
                if image_result and image_result.width and image_result.height
                    result.thumbnail.width = image_result.width
                    result.thumbnail.height = image_result.height
                else if result.thumbnail
                    delete result.thumbnail

                callback()

                request.abort()
            )
        )
    else
        callback()



# New v2 handler
app.get('/parseContent', (req, res) ->
    req.query.version = 2
    parse(req, res)
)

# Legacy support
app.get('/parse', parse)


# --- Expose functions
attachTitle = (version, result, title, url) ->
    if title and title.length > 0
        result.title = title
    else
        result.title = url

attachUrl = (version, result, url) ->
    if version == 1
        result.matched_url = url
    else
        result.url = url

attachType = (version, result, url) ->
    result.type = "website"


attachThumbnail = (version, result, thumb_info) ->
    if version == 1
        result.thumbnail_url = thumb_info[0]
        result.thumbnail_width = thumb_info[1]
        result.thumbnail_height = thumb_info[2]
    else
        result.thumbnail = {
            "url": thumb_info[0],
            "width": thumb_info[1],
            "height": thumb_info[2]
        }


# --- Providers
app.get('/providers', (req, res) ->
    res.set({'Content-Type': 'application/json'})
    res.send(media_parser.getProviders())
)


# --- Handle error gracefully
process.on('uncaughtException', (err)  ->
    console.log(err)
)


# --- Command line setup
usage = "A specialized API for handling oemebed requests"

program
  .version('2.0.0')
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
