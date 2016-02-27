fs = require 'fs'
PathUtil = require('path').posix
VFileSystem = require '../vfilesystem'
FTPFile = require './ftp-file'
FTPDirectory = require './ftp-directory'
SFTPSession = require './sftp-session'
Utils = require '../../utils'

module.exports =
class SFTPFileSystem extends VFileSystem

  constructor: (@server, @config) ->
    super();
    @session = null;
    @client = null;

    if @config.password? and !@config.passwordDecrypted?
      @config.password = Utils.decrypt(@config.password, @getDescription());
      @config.passwordDecrypted = true;

    @clientConfig = @getClientConfig();

  clone: ->
    cloneFS = new SFTPFileSystem(@server, @config);
    cloneFS.clientConfig = @clientConfig;
    return cloneFS;

  isLocal: ->
    return false;

  connectImpl: ->
    @session = new SFTPSession(@);
    @session.connect();

  disconnectImpl: ->
    if @session?
      @session.disconnect();

  sessionOpened: (session) ->
    if session == @session
      @client = session.getClient();
      @setConnected(true);

  sessionCanceled: (session) ->
    if session == @session
      @session = null;
      @setConnected(false);

  sessionClosed: (session) ->
    if session == @session
      @session = null;
      @client = null;
      @setConnected(false);

  getClientConfig: ->
    result = {};

    result.host = @config.host;
    result.port = @config.port;
    result.username = @config.username;
    result.password = @config.password;
    result.tryKeyboard = true;
    result.keepaliveInterval = 60000;

    return result;

  getSafeConfig: ->
    result = {};

    for key, val of @config
      result[key] = val;

    if @config.storePassword
      result.password = Utils.encrypt(result.password, @getDescription());
    else
      delete result.password;

    delete result.passwordDecrypted;

    return result;

  getFile: (path) ->
    return new FTPFile(@, false, path);

  getDirectory: (path) ->
    return new FTPDirectory(@, false, path);

  getItemWithPathDescription: (pathDescription) ->
    if pathDescription.isFile
      return new FTPFile(@, pathDescription.isLink, pathDescription.path, pathDescription.name);

    return new FTPDirectory(@, pathDescription.isLink, pathDescription.path);

  getInitialDirectory: ->
    return @getDirectory(@config.folder);

  getURI: (item) ->
    return @config.protocol+"://" + PathUtil.join(@config.host, item.path);

  getPathUtil: ->
    return PathUtil;

  getPathFromURI: (uri) ->
    root = @config.protocol+"://"+@config.host;

    if uri.substring(0, root.length) == root
      return uri.substring(root.length);

    return null;

  renameImpl: (oldPath, newPath, callback) ->
    @client.rename oldPath, newPath, (err) =>
      if !callback?
        return;

      if err?
        callback(err);
      else
        callback(null);

  makeDirectoryImpl: (path, callback) ->
    @client.mkdir path, [], (err) =>
      if !callback?
        return;

      if err?
        callback(err);
      else
        callback(null);

  deleteFileImpl: (path, callback) ->
    @client.unlink path, (err) =>
      if !callback?
        return;

      if err?
        callback(err);
      else
        callback(null);

  deleteDirectoryImpl: (path, callback) ->
    @client.rmdir path, (err) =>
      if !callback?
        return;

      if err?
        callback(err);
      else
        callback(null);

  getName: ->
    return @config.host;

  getID: ->
    return @getLocalDirectoryName();

  getLocalDirectoryName: ->
    return @config.protocol+"_"+@config.host+"_"+@config.port+"_"+@config.username;

  downloadImpl: (path, localPath, callback) ->
    @client.fastGet(path, localPath, {}, callback);

  uploadImpl: (localPath, path, callback) ->
    @client.fastPut(localPath, path, {}, callback);

  openFile: (file) ->
    @server.getRemoteFileManager().openFile(file);

  createReadStreamImpl: (path, callback) ->
    rs = @client.createReadStream(path);
    callback(null, rs);

  getDescription: ->
    return @config.protocol+"://"+@config.host+":"+@config.port;

  getEntriesImpl: (directory, callback) ->
    @list directory.getPath(), (err, entries) =>
      callback(directory, err, entries);

  list: (path, callback) ->
    @client.readdir path, (err, entries) =>
      if err?
        callback(err, []);
      else
        callback(null, @wrapEntries(path, entries));

  wrapEntries: (path, entries) ->
    directories = [];
    files = [];

    for entry in entries
      wrappedEntry = @wrapEntry(path, entry);

      if wrappedEntry != null
        if wrappedEntry.isFile()
          files.push(wrappedEntry);
        else
          directories.push(wrappedEntry);

    Utils.sortItems(files);
    Utils.sortItems(directories);

    return directories.concat(files);

  wrapEntry: (path, entry) ->
    if entry.attrs.isDirectory()
      return new FTPDirectory(@, false, PathUtil.join(path, entry.filename));
    else if entry.attrs.isFile()
      return new FTPFile(@, false, PathUtil.join(path, entry.filename));
    # else if entry.attrs.isSymbolicLink()
      # console.log(entry)
      # TODO : Support symbolic links.

    return null;

  newFileImpl: (path, callback) ->
    @client.open path, "w", {}, (err, handle) =>
      if err?
        callback(null);
        return;

      @client.close handle, (err) =>
        if err?
          callback(null);
          return;

        callback(@getFile(path));
