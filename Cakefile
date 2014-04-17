{spawn, exec} = require 'child_process'

option '-p', '--prefix [DIR]', 'set the installation prefix for `cake install`'

task 'build', 'continually build the media-server library with --watch', ->
  coffee = spawn 'coffee', ['-c', '-o', 'lib', 'src']
  coffee.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'install', 'install the `media-server` command into /usr/local (or --prefix)', (options) ->
  base = options.prefix or '/usr/local'
  lib  = base + '/lib/media-server'
  exec([
    'mkdir -p ' + lib
    'cp -rf bin README.md lib ' + lib
    'ln -sf ' + lib + '/bin/media-server ' + base + '/bin/media-server'
  ].join(' && '), (err, stdout, stderr) ->
   if err then console.error stderr
  )
