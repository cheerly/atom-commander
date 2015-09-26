fs = require 'fs'
FTPClient = require 'ftp'
PathUtil = require 'path'
VFileSystem = require '../vfilesystem'
FTPFile = require './ftp-file'
FTPDirectory = require './ftp-directory'
Utils = require '../../utils'

module.exports =
class FTPFileSystem extends VFileSystem

  constructor: (@server, @config) ->
    super();
    @client = null;

    if @config.password? and !@config.passwordDecrypted?
      @config.password = Utils.decrypt(@config.password, @getDescription());
      @config.passwordDecrypted = true;

    @clientConfig = @getClientConfig();

  isLocal: ->
    return false;

  connectImpl: ->
    if @clientConfig.password?
      @connectWithPassword(@clientConfig.password);
    else
      Utils.promptForPassword "Enter password:", (password) =>
        if password?
          @connectWithPassword(password);

  connectWithPassword: (password) ->
    @client = new FTPClient();

    @client.on "ready", =>
      @clientConfig.password = password;
      @setConnected(true);

    @client.on "close", =>
      @disconnect();

    @client.on "error", (err) =>
      message = "Error connecting to "+@getDescription()+".";
      if err.message?
        message += "\n"+err.message;

      @disconnect(err);

    @client.on "end", =>
      @disconnect();

    connectConfig = {};

    for key, val of @clientConfig
      connectConfig[key] = val;

    connectConfig.password = password;

    @client.connect(connectConfig);

  disconnectImpl: ->
    if @client?
      @client.logout =>
        @client.end();
        @client = null;

    @setConnected(false);

  getClientConfig: ->
    result = {};

    result.host = @config.host;
    result.port = @config.port;
    result.user = @config.user;
    result.password = @config.password;

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
        callback(err.message);
      else
        callback(null);

  makeDirectoryImpl: (path, callback) ->
    @client.mkdir path, true, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  deleteFileImpl: (path, callback) ->
    @client.delete path, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  deleteDirectoryImpl: (path, callback) ->
    @client.rmdir path, (err) =>
      if !callback?
        return;

      if err?
        callback(err.message);
      else
        callback(null);

  getID: ->
    return @getLocalDirectoryName();

  getLocalDirectoryName: ->
    return @config.protocol+"_"+@config.host+"_"+@config.port+"_"+@config.user;

  downloadImpl: (path, localPath, callback) ->
    @client.get path, (err, stream) =>
      if err?
        callback(err);
        return;

      stream.on("error", callback);
      stream.on("end", callback);
      stream.pipe(fs.createWriteStream(localPath));

  uploadImpl: (localPath, path, callback) ->
    @client.put(localPath, path, false, callback);

  newFileImpl: (path, callback) ->
    buffer = new Buffer("", "utf8");
    @client.put buffer, path, (err) =>
      if err?
        callback(null);
      else
        callback(@getFile(path));

  openFile: (file) ->
    @server.openFile(file);

  createReadStreamImpl: (path, callback) ->
    @client.get(path, callback);

  getDescription: ->
    return @config.protocol+"://"+@config.host+":"+@config.port;

  getEntriesImpl: (directory, callback) ->
    @list directory.getPath(), (err, entries) =>
      callback(directory, err, entries);

  list: (path, callback) ->
    @client.list path, (err, entries) =>
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
    if (entry.name == ".") or (entry.name == "..")
      return null;

    if (entry.type == "d")
      return new FTPDirectory(@, false, PathUtil.join(path, entry.name));
    else if entry.type == "-"
      return new FTPFile(@, false, PathUtil.join(path, entry.name));
    else if (entry.type == "l")
      if entry.target.length >= 1 && entry.target[entry.target.length - 1] == '/'
        return new FTPDirectory(@, true, PathUtil.join(path, entry.name));
      else
        return new FTPFile(@, true, PathUtil.resolve(path, entry.target), entry.name);

    return null;
