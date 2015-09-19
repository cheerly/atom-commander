module.exports =
class VItem

  constructor: (@fileSystem) ->

  getFileSystem: ->
    return @fileSystem;

  getURI: ->
    return @fileSystem.getURI(@);

  getPath: ->
    return @getRealPathSync();

  delete: (callback) ->
    if @isFile()
      @fileSystem.deleteFile(@getPath(), callback);
    else if @isDirectory()
      @fileSystem.deleteDirectory(@getPath(), callback);

  isFile: ->

  isDirectory: ->

  isLink: ->

  isWritable: ->

  existsSync: ->

  getRealPathSync: ->

  getBaseName: ->

  getParent: ->
