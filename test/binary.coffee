autoprefixer = require('../lib/autoprefixer')
Binary       = require('../lib/autoprefixer/binary')

fs     = require('fs')
os     = require('os')
child  = require('child_process')

class StringBuffer
  constructor: -> @content  = ''
  write: (str) -> @content += str
  resume:      -> @resumed  = true
  on: (event, callback) ->
    if event == 'data' and @resumed
      callback(@content)
    else if event == 'end'
      callback()

tempDir = os.tmpdir() + '/' + (new Date).valueOf()

write = (file, css) ->
  fs.mkdirSync(tempDir) unless fs.existsSync(tempDir)
  fs.writeFileSync("#{tempDir}/#{file}", css)

read = (file) ->
  fs.readFileSync("#{tempDir}/#{file}").toString()

describe 'Binary', ->
  beforeEach ->
    @stdout = new StringBuffer()
    @stderr = new StringBuffer()
    @stdin  = new StringBuffer()

    @exec = (args..., callback) ->
      args = args.map (i) ->
        if i.match(/\.css/)
          "#{tempDir}/#{i}"
        else
          i

      binary = new Binary
        argv:   ['', ''].concat(args)
        stdin:  @stdin
        stdout: @stdout
        stderr: @stderr

      binary.run =>
        if binary.status == 0 and @stderr.content == ''
          error = false
        else
          error = @stderr.content
        callback(@stdout.content, error)

  afterEach ->
    if fs.existsSync(tempDir)
      fs.unlinkSync("#{tempDir}/#{i}") for i in fs.readdirSync(tempDir)
      fs.rmdirSync(tempDir)

  css      = 'a { transition: all 1s; }'
  prefixed = "a {\n  -webkit-transition: all 1s;\n  transition: all 1s;\n}"

  it 'should show version', (done) ->
    @exec '-v', (out, err) ->
      err.should.be.false
      out.should.match(/^autoprefixer [\d\.]+\n$/)
      done()

  it 'should show help', (done) ->
    @exec '-h', (out, err) ->
      err.should.be.false
      out.should.match(/Usage:/)
      done()

  it 'should inspect', (done) ->
    @exec '-i', (out, err) ->
      err.should.be.false
      out.should.match(/Browsers:/)
      done()

  it 'should use 2 last browsers by default', (done) ->
    chrome = autoprefixer.data.browsers.chrome.versions
    @exec '-i', (out, err) ->
      out.should.include("Chrome: #{ chrome[0] }, #{ chrome[1] }")
      done()

  it 'should change browsers', (done) ->
    @exec '-i', '-b', 'ie 6', (out, err) ->
      out.should.match(/IE: 6/)
      done()

  it 'should rewrite several files', (done) ->
    write('a.css', css)
    write('b.css', css + css)
    @exec '-b', 'chrome 25', 'a.css', 'b.css', (out, err) ->
      err.should.be.false
      out.should.eql ''
      read('a.css').should.eql prefixed
      read('b.css').should.eql prefixed + "\n\n" + prefixed
      done()

  it 'should change output file', (done) ->
    write('a.css', css)
    @exec '-b', 'chrome 25', 'a.css', '-o', 'b.css', (out, err) ->
      err.should.be.false
      out.should.eql ''
      read('a.css').should.eql css
      read('b.css').should.eql prefixed
      done()

  it 'should output to stdout', (done) ->
    write('a.css', css)
    @exec '-b', 'chrome 25', '-o', '-', 'a.css', (out, err) ->
      err.should.be.false
      out.should.eql prefixed + "\n"
      read('a.css').should.eql css
      done()

  it 'should read from stdin', (done) ->
    @stdin.content = css
    @exec '-b', 'chrome 25', (out, err) ->
      err.should.be.false
      out.should.eql prefixed + "\n"
      done()

  it "should raise error, when files doesn't exists", (done) ->
    @exec 'a', (out, err) ->
      out.should.be.empty
      err.should.match(/autoprefixer: File a doesn't exists/)
      done()

  it 'should raise error on unknown argumnets', (done) ->
    @exec '-x', (out, err) ->
      out.should.be.empty
      err.should.match(/autoprefixer: Unknown argument -x/)
      done()

  it 'should nice print errors', (done) ->
    @exec '-b', 'ie', (out, err) ->
      out.should.be.empty
      err.should.eql("autoprefixer: Unknown browser requirement `ie`\n")
      done()

describe 'bin/autoprefixer', ->

  it 'should be executable', (done) ->
    binary = __dirname + '/../bin/autoprefixer'
    child.execFile binary, ['-v'], { }, (error, out) ->
      (!!error).should.be.false
      out.should.match(/^autoprefixer [\d\.]+\n$/)
      done()
