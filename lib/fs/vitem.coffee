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

  getPathDescription: ->
    result = {};

    result.isLink = @isLink();
    result.isFile = @isFile();
    result.path = @getPath();
    result.name = @getBaseName();
    result.isLocal = @fileSystem.isLocal();
    result.fileSystemId = @fileSystem.getID();
    result.uri = @getURI();

    return result;

  isLocal: ->
    return @fileSystem.isLocal();

  isRemote: ->
    return @fileSystem.isRemote();

  isFile: ->

  isDirectory: ->

  isLink: ->

  isWritable: ->

  existsSync: ->

  getRealPathSync: ->

  getBaseName: ->

  getParent: ->
