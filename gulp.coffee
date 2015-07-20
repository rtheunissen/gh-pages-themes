###
╔═╗╦ ╦╦  ╔═╗
║ ╦║ ║║  ╠═╝
╚═╝╚═╝╩═╝╩
###


# Returns a list of files relative to a base directory
from = (directory, files) ->
    [].concat(files).map (file) -> path.join(directory, file)


# Returns a file path relative to the base asset path
asset = (file) ->
    path.join(paths.assets, file)


#
mixed_scripts = (files) ->
    from paths.assets + '/scripts', files.map((path) -> path + '.{coffee,js}')


# Base paths
paths =
    themes: 'themes'
    assets: 'assets'  # base asset directory
    build:  'build'   # build directory

files =
    build:
        css: 'theme.css'
        js:  'theme.js'

    watch:
        scripts: '**.{coffee,js}'
        styles:  '**.{less,css}'
        ignore:  [
            'node_modules'
        ]

    styles:
        less: asset 'styles/less/theme.less'

    scripts:
        other:
            mixed_scripts []


# Used to apply a conditional filter.
# Returns the condition if no filter was provided.
conditional = (condition, filter) ->
    if filter then gulpif(condition, filter) else condition


# Combines multiple streams in the same order that they are provided.
streams = () ->
    q = new streamqueue(objectMode: true)
    q.queue arg for arg in arguments
    q.done()


# Default error handler, shows a notification but no sound
onError = (error) ->
  notify.onError(
    title: "<%= error.name %>",
    subtitle: "<%= path.basename(error.filename) %>",
    message: "<%= error.message %>"
    sound: false
  ) error
  @emit 'end'


# Wraps around gulp.src and attaches the default error handler
open = (glob, options) ->
    console.log glob, options

    gulp
      .src(glob, options or {})
      .pipe debug()
      .pipe plumber(errorHandler: onError)


###
╔═╗╔╦╗╦ ╦╦  ╔═╗╔═╗
╚═╗ ║ ╚╦╝║  ║╣ ╚═╗
╚═╝ ╩  ╩ ╩═╝╚═╝╚═╝
###

styles = (dir) ->

    ###
    ┬  ┌─┐┌─┐┌─┐
    │  ├┤ └─┐└─┐
    ┴─┘└─┘└─┘└─┘
    ###

    less = () ->
      open(files.styles.less, cwd: dir)
        .pipe lessc()

    # Combine all style steams into one
    streams(less())
      .pipe postcss [autoprefixer(), mqpacker, csswring]
      .pipe concat(files.build.css)


###
╔═╗╔═╗╦═╗╦╔═╗╔╦╗╔═╗
╚═╗║  ╠╦╝║╠═╝ ║ ╚═╗
╚═╝╚═╝╩╚═╩╩   ╩ ╚═╝
###

scripts = (dir) ->

    ###
    ┌─┐┌┬┐┬ ┬┌─┐┬─┐
    │ │ │ ├─┤├┤ ├┬┘
    └─┘ ┴ ┴ ┴└─┘┴└─
    ###

    other = () ->
        # Return an open stream to be combined later on.
        # Only applies the coffeescript filter to .coffee files
        open(files.scripts.other, cwd: dir)
            .pipe gulpif(/[.]coffee$/, coffee(bare: true))

    # Combine all script streams in order to prepare for build
    streams(other())
        .pipe concat(files.build.js)
        .pipe uglify()


###
╔╦╗╔═╗╔═╗╦╔═╔═╗
 ║ ╠═╣╚═╗╠╩╗╚═╗
 ╩ ╩ ╩╚═╝╩ ╩╚═╝
###

# Only groups and writes the file - no versioning or compression
build = (stream, dir) ->
    stream
        .pipe gulp.dest(path.join(dir, paths.build))
        .pipe livereload()


# A wrapper around chokidar which is a wrapper around nodejs' fs.watch
watch = (src, tasks) ->
    options =
        ignoreInitial: true
        ignored: files.watch.ignore

    chokidar.watch(src, options).on 'all', -> tasks()


# This is the basic build script, usually referenced by other tasks
gulp.task 'build', ->

  fs.readdirSync(paths.themes).map (dir) ->

    relative = path.join(paths.themes, dir)

    build(scripts(relative), relative)
    build(styles(relative), relative)


# Automatically re-compile assets when they are modified.
gulp.task 'watch', ->
    livereload.listen()

    watch path.join(paths.themes, '**', 'assets', files.watch.styles),   gulp.parallel('build')
    watch path.join(paths.themes, '**', 'assets', files.watch.scripts),  gulp.parallel('build')

    gulp.parallel('build')()


# Default task to run when using 'gulp'.
gulp.task 'default', gulp.parallel('build')
