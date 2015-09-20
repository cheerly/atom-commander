fs = require 'fs'
PathUtil = require 'path'
FTPClient = require 'ftp'
SSH2 = require 'ssh2'
VFileSystem = require '../vfilesystem'
FTPFile = require './ftp-file'
FTPDirectory = require './ftp-directory'
Utils = require '../../utils'

module.exports =
class SFTPFileSystem extends VFileSystem

  constructor: (@server, @config) ->
    super();
    @connected = false;
    @client = null;

    if @config.password? and !@config.passwordDecrypted?
      @config.password = Utils.decrypt(@config.password, @getDescription());
      @config.passwordDecrypted = true;

    @clientConfig = @getClientConfig();

  isLocal: ->
    return false;

  connect: ->
    if @clientConfig.password?
      @connectWithPassword(@clientConfig.password);
    else
      Utils.promptForPassword "Enter password:", (password) =>
        if password?
          @connectWithPassword(password);

  connectWithPassword: (password) ->
    @client = null;
    @ssh2 = new SSH2();

    @ssh2.on "ready", =>
      @ssh2.sftp (err, sftp) =>
        if err?
          @disconnect();
          return;

        @client = sftp;

        @client.on "end", =>
          @disconnect();

        # If the connection was successful then remember the password for
        # the rest of the session.
        @clientConfig.password = password;
        @setConnected(true);

    @ssh2.on "close", =>
      @disconnect();

    @ssh2.on "error", (err) =>
      message = "Error connecting to "+@getDescription()+".";
      if err.message?
        message += "\n"+err.message;

      atom.notifications.addWarning(message);
      console.log(err);
      @disconnect();

    @ssh2.on "end", =>
      @disconnect();

    @ssh2.on "keyboard-interactive", (name, instructions, instructionsLang, prompt, finish) =>
      finish([password]);

    connectConfig = {};

    for key, val of @clientConfig
      connectConfig[key] = val;

    connectConfig.password = password;

    @ssh2.connect(connectConfig);

  disconnect: ->
    if @client?
      @client.end();
      @client = null;

    if @ssh2?
      @ssh2.end();
      @ssh2 = null;

    @setConnected(false);

  isConnected: ->
    return @connected and (@client != null);

  setConnected: (connected) ->
    if @connected == connected
      return;

    @connected = connected;

    if @connected
      @emitConnected();
    else
      @emitDisconnected();

  getClientConfig: ->
    result = {};

    result.host = @config.host;
    result.port = @config.port;
    result.username = @config.username;
    result.password = @config.password;
    result.tryKeyboard = true;

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

  getInitialDirectory: ->
    return @getDirectory(@config.folder);

  getURI: (item) ->
    return @config.protocol+"://" + PathUtil.join(@config.host, item.path);

  getPathFromURI: (uri) ->
    root = @config.protocol+"://"+@config.host;

    if uri.substring(0, root.length) == root
      return uri.substring(root.length);

    return null;

  rename: (oldPath, newPath, callback) ->
    @client.rename oldPath, newPath, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  makeDirectory: (path, callback) ->
    @client.mkdir path, [], (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  deleteFile: (path, callback) ->
    @client.unlink path, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  deleteDirectory: (path, callback) ->
    @client.rmdir path, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  getLocalDirectoryName: ->
    return @config.host + "_" + @config.port + "_" + @config.username;

  download: (path, localPath, callback) ->
    @client.fastGet(path, localPath, {}, callback);

  upload: (localPath, path, callback) ->
    @client.fastPut(localPath, path, {}, callback);

  openFile: (file) ->
    @server.getRemoteFileManager().openFile(file);

  getDescription: ->
    return @config.protocol+"://"+@config.host+":"+@config.port;

  list: (path, callback) ->
    @client.readdir path, (err, entries) =>
      if err?
        console.log(err);
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
      if entry.attrs.isSymbolicLink()
        return new FTPDirectory(@, true, PathUtil.join(path, entry.filename));
      else
        return new FTPDirectory(@, false, PathUtil.join(path, entry.filename));
    else if entry.attrs.isFile()
      if entry.attrs.isSymbolicLink()
        # TODO : Support symbolic links to files.
        # return new FTPFile(@, true, PathUtil.resolve(path, entry.target), entry.name);
      else
        return new FTPFile(@, false, PathUtil.join(path, entry.filename));

    return null;

  newFile: (path, callback) ->
    @client.open path, "w", {}, (err, handle) =>
      if err?
        callback(null);
        return;

      @client.close handle, (err) =>
        if err?
          callback(null);
          return;

        callback(@getFile(path));
