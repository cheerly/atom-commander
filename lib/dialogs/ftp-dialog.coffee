Client = require 'ftp'
FTPFileSystem = require '../fs/ftp/ftp-filesystem'
{View, TextEditorView} = require 'atom-space-pen-views'

module.exports =
class FTPDialog extends View

  constructor: (@containerView) ->
    super();
    @messageType = 0;
    @username = "";
    @client = null;

  @content: ->
    @div class: "atom-commander-ftp-dialog", =>
      @div "New FTP Connection", {class: "heading"}
      @table =>
        @tbody =>
          @tr =>
            @td "URL", {class: "text-highlight"}
            @td "ftp://", {outlet: "url"}
          @tr =>
            @td "Server", {class: "text-highlight"}
            @td =>
              @subview "serverEditor", new TextEditorView(mini: true)
          @tr =>
            @td "Port", {class: "text-highlight"}
            @td =>
              @subview "portEditor", new TextEditorView(mini: true)
          @tr =>
            @td "Anonymous", {class: "text-highlight"}
            @td =>
              @input {type: "checkbox", outlet: "anonymous"}
          @tr =>
            @td "Username", {class: "text-highlight"}
            @td =>
              @subview "usernameEditor", new TextEditorView(mini: true)
          @tr =>
            @td "Password", {class: "text-highlight"}
            @td {class: "password"}, =>
              @subview "passwordEditor", new TextEditorView(mini: true)
      @div {class: "test-button-panel"}, =>
        @button "Test", {class: "btn", click: "test"}
      @div {class: "bottom-button-panel"}, =>
        @button "Cancel", {class: "btn", click: "cancel"}
        @button "OK", {class: "btn", click: "confirm"}
      @div =>
        @span {class: "loading loading-spinner-tiny inline-block", outlet: "spinner"}
        @span {class: "message", outlet: "message"}

  initialize: ->
    @spinner.hide();
    @portEditor.getModel().setText("21");

    @serverEditor.getModel().onDidChange =>
      @refreshURL();
      @refreshError();

    @portEditor.getModel().onDidChange =>
      @refreshURL();
      @refreshError();

    @usernameEditor.getModel().onDidChange =>
      if !@isAnonymousSelected()
        @username = @usernameEditor.getModel().getText().trim();
      @refreshError();

    @passwordEditor.getModel().onDidChange =>
      @refreshError();

    @anonymous.change =>
      @anonymousChanged();

    atom.commands.add @element,
      "core:confirm": => @confirm()
      "core:cancel": => @cancel()
    # @miniEditor.on 'blur', => @close()a
    # @miniEditor.getModel().onDidChange => @showError()
    # @miniEditor.getModel().setText(initialPath)

    @refreshError();

  getPort: ->
    port = @portEditor.getModel().getText().trim();

    if port.length == 0
      return 21;

    port = parseInt(port);

    if isNaN(port)
      return null;

    return port;

  anonymousChanged: ->
    selected = @isAnonymousSelected();

    if selected
      @usernameEditor.getModel().setText("anonymous");
    else
      @usernameEditor.getModel().setText(@username);

    @refreshError();

  isAnonymousSelected: ->
    return @anonymous.is(":checked");

  refreshURL: ->
    server = @serverEditor.getModel().getText().trim();
    port = @portEditor.getModel().getText().trim();

    url = "ftp://" + server;

    if (server.length > 0)
      port = @getPort();

      if (port != null) and (port != 21)
        url += ":" + port;

    @url.text(url);

  refreshError: ->
    message = @getErrorMessage();

    if (message == null)
      @showMessage("", 0);
    else
      @showMessage(message, 2);

  getErrorMessage: ->
    if @serverEditor.getModel().getText().trim().length == 0
      return "Server must be specified."

    if @getPort() == null
      return "Invalid port number.";

    return null;

  showMessage: (text, type) ->
    @messageType = type;

    @message.removeClass("text-error");
    @message.removeClass("text-warning");
    @message.removeClass("text-success");

    if @messageType == 0
      @message.addClass("text-success");
    else if @messageType == 1
      @message.addClass("text-warning");
    else
      @message.addClass("text-error");

    @message.text(text);

  getFTPConfig: ->
    config = {};

    config.host = @serverEditor.getModel().getText().trim();
    config.port = @getPort();

    if @isAnonymousSelected()
      config.user = "anonymous";
      config.password = "anonymous@";
    else
      config.user = @username;
      config.password = @passwordEditor.getModel().getText().trim();

    return config;

  attach: ->
    @panel = atom.workspace.addModalPanel(item: this.element)
    @serverEditor.focus()
    @serverEditor.getModel().scrollToCursorPosition()

  close: ->
    panelToDestroy = @panel;
    @panel = null;
    panelToDestroy?.destroy();
    @containerView.requestFocus();

  confirm: ->
    if @hasError()
      return;

    @close();

    ftpFileSystem = new FTPFileSystem(@getFTPConfig());
    directory = ftpFileSystem.getDirectory("/");

    @containerView.openDirectory(directory);

  cancel: ->
    @close();

  hasError: ->
    return @messageType == 2;

  test: ->
    if @hasError() or (@client != null)
      return;

    @client = new Client();

    @client.on "ready", =>
      @spinner.hide();
      @showMessage("Connection successful", 0);
      @client.end();
      @client = null;

    @client.on "error", (err) =>
      @spinner.hide();
      @showMessage("Connection failed", 1);
      @client.end();
      @client = null;

    @spinner.show();
    @client.connect(@getFTPConfig());
