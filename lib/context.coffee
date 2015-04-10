fs   = require 'fs'
path = require 'path'
util = require 'util'
selectedTest = require './selected-test'

exports.find = (editor) ->
  root = closestPackage editor.getPath()
  if root
    latteBinary = path.join root, 'node_modules', '.bin', 'triple-latte'
    if not fs.existsSync latteBinary
      latteBinary = 'triple-latte'
    root: root
    test: path.relative root, editor.getPath()
    grep: selectedTest.fromEditor editor
    tripleLatte: latteBinary
  else
    root: path.dirname editor.getPath()
    test: path.basename editor.getPath()
    grep: selectedTest.fromEditor editor
    tripleLatte: 'triple-latte'

closestPackage = (folder) ->
  pkg = path.join folder, 'package.json'
  if fs.existsSync pkg
    folder
  else if folder is '/'
    null
  else
    closestPackage path.dirname(folder)
