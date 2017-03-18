fs = require 'fs'
SSH2 = require 'ssh2'
Utils = require '../../utils'

module.exports =
class SFTPSession

  constructor: (@fileSystem) ->
    @config = @fileSystem.config;
    @clientConfig = @fileSystem.clientConfig;

    @client = null;
    @ssh2 = null;
    @open = null;

  getClient: ->
    return @client;

  # Called if connecting failed due to invalid credentials. This will only try
  # to connect again if a password or passphrase should be prompted for.
  reconnect: ->
    delete @clientConfig.password;
    delete @clientConfig.passphrase;

    if @config.loginWithPassword or @config.usePassphrase
      @connect();

  connect: ->
    if @config.loginWithPassword
      if @clientConfig.password? and @clientConfig.password.length > 0
        @connectWithPassword(@clientConfig.password);
        return;
    else # Login with private key.
      if @config.usePassphrase
        if @clientConfig.passphrase and @clientConfig.passphrase.length > 0
          @connectWithPassphrase(@clientConfig.passphrase);
          return;
      else
        @connectWithPrivateKey();
        return;

    password = @clientConfig.password;
    passphrase = @clientConfig.passphrase;

    if !password?
      password = '';

    if !passphrase?
      passphrase = '';

    @connectWith(password, passphrase);

    # If this point is reached then either a password or a passphrase needs to be entered.

    # prompt = "Enter ";
    # if @config.loginWithPassword
    #   prompt += "password for ";
    # else
    #   prompt += "passphrase for ";
    # prompt += @clientConfig.username;
    # prompt += "@";
    # prompt += @clientConfig.host;
    # prompt += ":"
    #
    # Utils.promptForPassword prompt, (input) =>
    #   if input?
    #     if @config.loginWithPassword
    #       @connectWithPassword(input);
    #     else
    #       @connectWithPassphrase(input);
    #   else
    #     err = {};
    #     err.canceled = true;
    #     err.message = "Incorrect credentials for "+@clientConfig.host;
    #     @fileSystem.emitError(err);
    #     @canceled();

  connectWithPassword: (password) ->
    @connectWith(password, '');

  connectWithPrivateKey: ->
    @connectWith('', '');

  connectWithPassphrase: (passphrase) ->
    @connectWith('', passphrase);

  # All connectWith? functions boil down to this one.
  #
  # password: The password that should be used. empty if not logging in with password.
  # passphrase: The passphrase to use when loggin in with a private key. empty if it shouldn't be used.
  connectWith: (password, passphrase) ->
    @client = null;
    @ssh2 = new SSH2();

    @ssh2.on "ready", =>
      @ssh2.sftp (err, sftp) =>
        if err?
          @fileSystem.emitError(err);
          @close();
          return;

        @client = sftp;

        @client.on "end", =>
          @close();

        # If the connection was successful then remember the password for
        # the rest of the session.
        if password.length > 0
          @clientConfig.password = password;

        if passphrase.length > 0
          @clientConfig.passphrase = passphrase;

        if @config.storePassword
          if password.length > 0
            @config.password = password;
          if passphrase.length > 0
            @config.passphrase = passphrase;
          @config.passwordDecrypted = true;

        @opened();

    @ssh2.on "error", (err) =>
      if err.level == "client-authentication"
        atom.notifications.addWarning("Incorrect credentials for "+@clientConfig.host);
        @reconnect();
      else
        @fileSystem.emitError(err);

    @ssh2.on "close", =>
      @close();

    @ssh2.on "end", =>
      @close();

    @ssh2.on "keyboard-interactive", (name, instructions, instructionsLang, prompt, finish) =>
      if password.length > 0
        finish([password]);
      else
        prompts = prompt.map (p) -> p.prompt;
        values = [];
        @prompt(0, prompts, values, finish);

    connectConfig = {};

    for key, val of @clientConfig
      connectConfig[key] = val;

    connectConfig.password = password;
    connectConfig.passphrase = passphrase;

    if (connectConfig.password.length == 0)
      delete connectConfig['password'];

    if (connectConfig.passphrase.length == 0)
      delete connectConfig['passphrase'];

    @ssh2.connect(connectConfig);

  disconnect: ->
    if @client?
      @client.end();
      @client = null;

    if @ssh2?
      @ssh2.end();
      @ssh2 = null;

    @close();

  opened: ->
    @open = true;
    @fileSystem.sessionOpened(@);

  canceled: ->
    @disconnect();
    @fileSystem.sessionCanceled(@);

  close: ->
    if @open
      @open = false;
      @fileSystem.sessionClosed(@);

  prompt: (index, prompts, values, finish) ->
    Utils.promptForPassword prompts[index], (input) =>
      if input?
        values.push(input);
        if prompts.length == (index + 1)
          finish(values);
        else
          @prompt(index + 1, prompts, values, finish);
      else
        err = {};
        err.canceled = true;
        err.message = "Incorrect credentials for "+@clientConfig.host;
        @fileSystem.emitError(err);
        @canceled();
