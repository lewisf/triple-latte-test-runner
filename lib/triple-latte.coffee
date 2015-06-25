fs     = require 'fs'
path   = require 'path'
util   = require 'util'
events = require 'events'
escape = require 'jsesc'
ansi   = require 'ansi-html-stream'
psTree = require 'ps-tree'
spawn  = require('child_process').spawn

clickablePaths = require './clickable-paths'

STATS_MATCHER = /\d+\s+(?:failing|passing|pending)/g

module.exports = class TripleLatteWrapper extends events.EventEmitter

  constructor: (@context, debugMode = false) ->
    @tripleLatte = null
    @node = atom.config.get 'triple-latte-test-runner.nodeBinaryPath'
    @textOnly = atom.config.get 'triple-latte-test-runner.textOnlyOutput'
    @options = atom.config.get 'triple-latte-test-runner.options'
    @env = atom.config.get 'triple-latte-test-runner.env'

    if debugMode
      optionsForDebug = atom.config.get 'triple-latte-test-runner.optionsForDebug'
      @options = "#{@options} #{optionsForDebug}"

    @resetStatistics()

  stop: ->
    if @tripleLatte?
      killTree(@tripleLatte.pid)
      @tripleLatte = null

  run: ->

    flags = [
      '--config'
      'test/config'
      '--timeout'
      '10000'
      @context.test
    ]

    env =
      PATH: path.dirname(@node)

    if @env
      for index, name of @env.split ' '
        [key, value] = name.split('=')
        env[key] = value

    if @textOnly
      flags.push '--no-colors'

    if @context.grep
      flags.push '--grep'
      flags.push @context.grep

    if @options
      Array::push.apply flags, @options.split ' '

    opts =
      cwd: @context.root
      env: env

    @resetStatistics()
    @tripleLatte = spawn @context.tripleLatte, flags, opts

    if @textOnly
      @tripleLatte.stdout.on 'data', (data) => @emit 'output', data.toString()
      @tripleLatte.stderr.on 'data', (data) => @emit 'output', data.toString()
    else
      stream = ansi(chunked: false)
      @tripleLatte.stdout.pipe stream
      @tripleLatte.stderr.pipe stream
      stream.on 'data', (data) =>
        @parseStatistics data
        @emit 'output', clickablePaths.link data.toString()

    @tripleLatte.on 'error', (err) =>
      @emit 'error', err

    @tripleLatte.on 'exit', (code) =>
      if code is 0
        @emit 'success', @stats
      else
        @emit 'failure', @stats

  resetStatistics: ->
    @stats = []

  parseStatistics: (data) ->
    while matches = STATS_MATCHER.exec(data)
      stat = matches[0]
      @stats.push(stat)
      @emit 'updateSummary', @stats


killTree = (pid, signal, callback) ->
  signal = signal or 'SIGKILL'
  callback = callback or (->)
  psTree pid, (err, children) ->
    childrenPid = children.map (p) -> p.PID
    [pid].concat(childrenPid).forEach (tpid) ->
      try
        process.kill tpid, signal
      catch ex
        console.log "Failed to #{signal} #{tpid}"
    callback()
