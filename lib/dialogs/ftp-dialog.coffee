Client = require 'ftp'
FTPFileSystem = require '../fs/ftp/ftp-filesystem'
{View, TextEditorView} = require 'atom-space-pen-views'

module.exports =
class FTPDialog extends View

  constructor: ->
    super();
    @username = "";
    @client = null;

  setParentDialog: (@parentDialog) ->

  @content: ->
    @div class: "atom-commander-ftp-dialog", =>
      # @div "New FTP Connection", {class: "heading"}
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
            @td "Folder", {class: "text-highlight"}
            @td =>
              @subview "folderEditor", new TextEditorView(mini: true)
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
          @tr =>
            @td "Remember Password", {class: "text-highlight"}
            @td =>
              @input {type: "checkbox", outlet: "storeCheckBox"}
          @tr =>
            @td =>
              @span "Passwords are encrypted", {class: "encrypted"}
      @div {class: "test-button-panel"}, =>
        @button "Test", {class: "btn", click: "test", outlet: "testButton"}
      @div {class: "bottom-button-panel"}, =>
        @button "Cancel", {class: "btn", click: "cancel", outlet: "cancelButton"}
        @button "OK", {class: "btn", click: "confirm", outlet: "okButton"}
      @div =>
        @span {class: "loading loading-spinner-tiny inline-block", outlet: "spinner"}
        @span {class: "message", outlet: "message"}

  initialize: ->
    @serverEditor.attr("tabindex", 1);
    @portEditor.attr("tabindex", 2);
    @folderEditor.attr("tabindex", 3);
    @anonymous.attr("tabindex", 4);
    @usernameEditor.attr("tabindex", 5);
    @passwordEditor.attr("tabindex", 6);
    @storeCheckBox.attr("tabindex", 7);
    @testButton.attr("tabindex", 8);
    @okButton.attr("tabindex", 9);
    @cancelButton.attr("tabindex", 10);

    @spinner.hide();
    @portEditor.getModel().setText("21");
    @storeCheckBox.prop("checked", true);

    @serverEditor.getModel().onDidChange =>
      @refreshURL();
      @refreshError();

    @portEditor.getModel().onDidChange =>
      @refreshURL();
      @refreshError();

    @folderEditor.getModel().onDidChange =>
      @refreshURL();

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

  isStoreCheckBoxSelected: ->
    return @storeCheckBox.is(":checked");

  getFolder: ->
    folder = @folderEditor.getModel().getText().trim();

    if (folder.length > 0)
      if folder[0] != "/"
        folder = "/"+folder;
    else
      folder = "/";

    return folder;

  refreshURL: ->
    server = @serverEditor.getModel().getText().trim();
    port = @portEditor.getModel().getText().trim();

    url = "ftp://" + server;

    if (server.length > 0)
      port = @getPort();

      if (port != null) and (port != 21)
        url += ":" + port;

    url += @getFolder();
    @url.text(url);

  refreshError: ->
    message = @getErrorMessage();

    if message != null
      @showMessage(message, 2);
      return;

    message = @getWarningMessage();

    if message != null
      @showMessage(message, 1);
      return;

    @showMessage("", 0);

  getErrorMessage: ->
    if @serverEditor.getModel().getText().trim().length == 0
      return "Server must be specified."

    if @getPort() == null
      return "Invalid port number.";

    return null;

  getWarningMessage: ->
    if !@isAnonymousSelected()
      if @passwordEditor.getModel().getText().trim().length == 0
        return "Password not specified."

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

    config.protocol = "ftp";
    config.host = @serverEditor.getModel().getText().trim();
    config.port = @getPort();
    config.folder = @getFolder();
    config.passwordDecrypted = true;

    if @isAnonymousSelected()
      config.anonymous = true;
      config.user = "anonymous";
      config.password = "anonymous@";
      config.storePassword = true;
    else
      config.anonymous = false;
      config.user = @username;
      config.password = @passwordEditor.getModel().getText().trim();
      config.storePassword = @isStoreCheckBoxSelected();

    return config;

  selected: ->
    @serverEditor.focus();

  # attach: ->
  #   @panel = atom.workspace.addModalPanel(item: this.element);
  #   @serverEditor.focus();
  #   @serverEditor.getModel().scrollToCursorPosition();

  close: ->
    @parentDialog.close();
    # panelToDestroy = @panel;
    # @panel = null;
    # panelToDestroy?.destroy();
    # @containerView.requestFocus();

  confirm: ->
    if @hasError()
      return;

    config = @getFTPConfig();

    if !config.storePassword and (config.password.length == 0)
      delete config.password;

    @parentDialog.addServer(config);

  cancel: ->
    @parentDialog.close();

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
