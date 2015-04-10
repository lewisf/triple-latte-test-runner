path        = require 'path'
context     = require './context'
TripleLatte = require './triple-latte'
ResultView  = require './result-view'

{CompositeDisposable} = require 'atom'

tripleLatte = null
resultView = null
currentContext = null

module.exports =
  config: # They are only read upon activation (atom bug?), thus the activationCommands for "settings-view:open" in package.json
    nodeBinaryPath:
      type: 'string'
      default: '/Users/lewis/.nvm/v0.10.21/bin/node'
      description: 'Path to the node executable'
    textOnlyOutput:
      type: 'boolean'
      default: false
      description: 'Remove any colors from the Mocha output'
    showContextInformation:
      type: 'boolean'
      default: false
      description: 'Display extra information for troubleshooting'
    options:
      type: 'string'
      default: ''
      description: 'Append given options always to Mocha binary'
    optionsForDebug:
      type: 'string'
      default: '--debug --debug-brk'
      description: 'Append given options to Mocha binary to enable debugging'
    env:
      type: 'string'
      default: ''
      description: 'Append environment variables'

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    resultView = new ResultView(state)

    @subscriptions.add atom.commands.add resultView, 'result-view:close', => @close()

    @subscriptions.add atom.commands.add 'atom-workspace', 'core:cancel', => @close()
    @subscriptions.add atom.commands.add 'atom-workspace', 'core:close', => @close()

    @subscriptions.add atom.commands.add 'atom-workspace', 'triple-latte-test-runner:run': => @run()
    @subscriptions.add atom.commands.add 'atom-workspace', 'triple-latte-test-runner:debug': => @run(true)
    @subscriptions.add atom.commands.add 'atom-workspace', 'triple-latte-test-runner:run-previous', => @runPrevious()
    @subscriptions.add atom.commands.add 'atom-workspace', 'triple-latte-test-runner:debug-previous', => @runPrevious(true)
    @subscriptions.add atom.commands.add 'atom-workspace', 'triple-latte-test-runner:run-all', => @runAll(true)

  deactivate: ->
    @close()
    @subscriptions.dispose()
    resultView = null

  serialize: ->
    resultView.serialize()

  close: ->
    if tripleLatte then tripleLatte.stop()
    resultView.detach()
    @resultViewPanel?.destroy()

  run: (inDebugMode = false) ->
    editor  = atom.workspace.getActivePaneItem()
    currentContext = context.find editor
    @execute(inDebugMode)

  runPrevious: (inDebugMode = false) ->
    if currentContext
      @execute(inDebugMode)
    else
      @displayError 'No previous test run'

  execute: (inDebugMode = false) ->

    resultView.reset()
    if not resultView.hasParent()
      @resultViewPanel = atom.workspace.addBottomPanel item:resultView

    if atom.config.get 'triple-latte-test-runner.showContextInformation'
      nodeBinary = atom.config.get 'triple-latte-test-runner.nodeBinaryPath'
      resultView.addLine "Node binary:           #{nodeBinary}\n"
      resultView.addLine "Root folder:           #{currentContext.root}\n"
      resultView.addLine "Path to triple-latte:  #{currentContext.tripleLatte}\n"
      resultView.addLine "Debug-Mode:            #{inDebugMode}\n"
      resultView.addLine "Test file:             #{currentContext.test}\n"
      resultView.addLine "Selected test:         #{currentContext.grep}\n\n"

    editor = atom.workspace.getActivePaneItem()
    tripleLatte  = new TripleLatte currentContext, inDebugMode

    tripleLatte.on 'success', -> resultView.success()
    tripleLatte.on 'failure', -> resultView.failure()
    tripleLatte.on 'updateSummary', (stats) -> resultView.updateSummary(stats)
    tripleLatte.on 'output', (text) -> resultView.addLine(text)
    tripleLatte.on 'error', (err) ->
      resultView.addLine('Failed to run Triple Latte\n' + err.message)
      resultView.failure()

    tripleLatte.run()


  displayError: (message) ->
    resultView.reset()
    resultView.addLine message
    resultView.failure()
    if not resultView.hasParent()
      atom.workspace.addBottomPanel item:resultView
