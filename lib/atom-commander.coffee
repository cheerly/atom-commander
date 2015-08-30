Actions = require './actions'
ListView = require './views/list-view'
DiffView = require './views/diff/diff-view'
AtomCommanderView = require './atom-commander-view'
{CompositeDisposable, File, Directory} = require 'atom'

module.exports = AtomCommander =
  mainView: null
  bottomPanel: null
  subscriptions: null

  activate: (@state) ->
    @bookmarks = [];

    @actions = new Actions(@);
    @mainView = new AtomCommanderView(@, @state);
    @bottomPanel = atom.workspace.addBottomPanel(item: @mainView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:toggle-visible': => @toggleVisible();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:toggle-focus': => @toggleFocus();

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-all': => @actions.selectAll();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-none': => @actions.selectNone();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-add': => @actions.selectAdd();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-remove': => @actions.selectRemove();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-invert': => @actions.selectInvert();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-folders': => @actions.selectFolders();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:select-files': => @actions.selectFiles();

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:mirror-view': => @actions.viewMirror();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:swap-view': => @actions.viewSwap();

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:compare-folders': => @actions.compareFolders();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:compare-files': => @actions.compareFiles();

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:go-project': => @actions.goProject();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:go-editor': => @actions.goEditor();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:go-drive': => @actions.goDrive();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:go-root': => @actions.goRoot();
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:go-home': => @actions.goHome();


    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:add-bookmark': => @actions.bookmarksAdd(false);
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:remove-bookmark': => @actions.bookmarksRemove(false);
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-commander:open-bookmark': => @actions.bookmarksOpen(false);

    @subscriptions.add atom.commands.add 'atom-text-editor', 'atom-commander:add-bookmark': (event) =>
      event.stopPropagation();
      @actions.bookmarksAddEditor();

    if @state.visible
      @bottomPanel.show();

    if @state.bookmarks?
      @bookmarks = @state.bookmarks;

  deactivate: ->
    @bottomPanel.destroy()
    @subscriptions.dispose()
    @mainView.destroy()

  serialize: ->
    if @mainView != null
      state = @mainView.serialize();
      state.visible = @bottomPanel.isVisible();
      state.bookmarks = @bookmarks;
      return state;

    return @state;

  toggleVisible: ->
    if @bottomPanel.isVisible()
      if (@mainView.focusedView != null) and @mainView.focusedView.hasFocus()
        @mainView.focusedView.unfocus();

      @bottomPanel.hide();
    else
      @bottomPanel.show();

  toggleFocus: ->
    if @bottomPanel.isVisible()
      if (@mainView.focusedView != null) and @mainView.focusedView.hasFocus()
        @mainView.focusedView.unfocus();
      else
        @mainView.refocusLastView();
    else
      @bottomPanel.show()
      @mainView.refocusLastView();

  addBookmark: (name, path) ->
    @bookmarks.push([name, path]);

  removeBookmark: (bookmark) ->
    index = @bookmarks.indexOf(bookmark);

    if (index >= 0)
      @bookmarks.splice(index, 1);
