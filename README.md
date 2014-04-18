# Embed media easily
media-embed-server is a node server that can parse content, extract links and return info about them. Info can be title, thumbnails, direct links etc. (depends on the service)

For some services it uses oEmbed, for others it uses other APIs.

It depends heavily on [media-parser](https://github.com/Doist/media-parser).


## Features
* Non-blocking parallel fetching of data
* Unified API for a lot of services
* Ability to cache results in memcached
* Minimal code base (around 100 lines for the server)
* Support for JSONP


## Installing the service
Installing the service is quite easy:
    
    npm install media-server-embed -g


## Running the service
The signature for running the service is:

    media-server-embed -p <port> -c <memcached (optional)>

An example:
    
    media-server-embed -p 8081 -c localhost:11211
    

# API endpoints

## /parse
Required arguments:
* **content**: Content to extract media information from.

Optional arguments:
* **timeout=5**: How long should we wait for the external service a timeout? Default is 5 sec.
* **min_tn_size=100:** Minimum thumbnail size. Default is 100. This is useful when a resource has multiple thumbnails in different sizes.
* **callback:** Wrap the result in a JavaScript function call (JSONP). Default is none.

### Example:
    
An example of a parse request:

    http://localhost:8080/parse?content=This+is+a+test+https://www.youtube.com/watch?v=lYHzdqGR9-U&min_tn_size=100

### Successful return:
A JSON list of matched URLs and information attached to the URL. Example:

    [
        {
            "matched_url": "https://www.youtube.com/watch?v=lYHzdqGR9-U",
            "title": "[프로리그2014] 정우용(CJ) vs 김유진(진에어) 2세트 해비테이션...",
            "thumbnail_width": 100,
            "thumbnail_height": 100,
            "thumbnail_url": "...",
            "raw": {
                ... RAW oemebed data ...
            }
        }
    ]
        
### Error Return
The errors are returned in the result dict as special JSON objects that have an error attribute. 
Example:

    [
        {
            "matched_url": "https://www.youtube.com/watch?v=lYHzdqGR9-U",
            "error": "Service timeout"
        }
    ] 

## /providers
Returns a list of providers that are supported, including a regular expressions that matches all the services that media-embed-server supports. If you store this regular expression locally you can answer locally if a service is supported or not.


Supported services
==================
- deviantart.com (oEmbed)
- flickr.com (oEmbed)
- hulu.com (oEmbed)
- justin.tv (oEmbed)
- rdio.com  (oEmbed)
- screenr.com  (oEmbed)
- slideshare.com (oEmbed)
- soundcloud.com (oEmbed)
- spotify.com (oEmbed)
- ted.com (oEmbed)
- vimeo.com (oEmbed)
- youtube.com (oEmbed)
- img.ly (custom)
- instagr.am (custom)
- twitpic.com (custom)
- yfrog.com (custom)


Authors
=======
* [Amir Salihefendic](https://github.com/amix)
* [Gonçalo Silva](https://github.com/goncalossilva)
