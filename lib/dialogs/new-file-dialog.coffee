fs = require 'fs-plus'
InputDialog = require '@aki77/atom-input-dialog'
Utils = require '../utils'

module.exports =
class NewFileDialog extends InputDialog

  constructor: (@containerView, @directory) ->
    super({prompt:'Enter a name for the new file:'});

  initialize: () ->
    options = {};
    options.callback = (text) =>
      name = text.trim();
      @directory.newFile name, (file, err) =>
        if file != null
          @containerView.refreshDirectory();
          @containerView.highlightIndexWithName(file.getBaseName());
          file.open();
        else
          Utils.showErrorWarning("Unable to create file "+name, null, null, err, true);

    options.validate = (text) ->
      name = text.trim();

      if name.length == 0
        return 'The file name may not be empty.'

      # file = @directory.getFile(name);

      # if fs.isFileSync(file.getRealPathSync())
      #   return "A file with this name already exists."

      return null;

    super(options);
