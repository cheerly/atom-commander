fsp = require 'fs-plus'
fse = require 'fs-extra'
path = require 'path'
{Directory, File} = require 'atom'

module.exports = (srcFolderPath, srcNames, dstFolderPath, move=false) ->
  callback = @async()
  dstDirectory = new Directory(dstFolderPath);

  try
    for srcName in srcNames
      srcPath = path.join(srcFolderPath, srcName);
      dstPath = path.join(dstFolderPath, srcName);

      srcIsDir = fsp.isDirectorySync(srcPath);

      # Prevent a folder from being moved into itself.
      stop = move and (dstPath.indexOf(srcPath) == 0);

      if !stop
        # TODO : Prompt user to choose if file should be replaced.
        # The src will be copied if:
        # - src is a folder
        # - src is a file and dst isn't a file
        if srcIsDir or !fsp.isFileSync(dstPath)
          fse.copySync(srcPath, dstPath);

          if move
            fse.removeSync(srcPath);

  catch error
    console.log("Error copying.");

  callback();
