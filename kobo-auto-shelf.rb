# vim: set fileencoding=utf-8 :


require 'sqlite3'
require 'uri'
require 'base64'


module PathUtil
  def self.escape_path (path)
    res = []
    P(path).ascend {|it| res << self.escape(it.basename.to_s) }
    P(res.last).join(*(res[0...-1].reverse))
  end

  def self.escape (s)
    s.to_s.split(/\./).map do
      |it|
      if it.bytes.all? {|c| (0x20 .. 0x7e) === c }
        it
      else
        opts = {:undef => :replace, :invalid => :replace, :replace => '='}
        Base64.encode64(it.encode('CP932', opts).to_s).gsub(/\n/, '').tr('/', '-')
      end
    end.join('.')
  end
end

class ShelfContent < Struct.new(:type, :id)
end

class Project
  attr_accessor :body_source_path
  attr_accessor :sd_source_path
  attr_accessor :body_path
  attr_accessor :sd_path

  def initialize
  end

  def run
    reset
    check!
    copy(:body, @body_source_path, @body_path) if @body_source_path and @body_path
    copy(:sd, @sd_source_path, @sd_path) if @sd_source_path and @sd_path
    make_shelf_all
  end

  private

  def dbfile_path
    @body_path.join('.kobo', 'KoboReader.sqlite')
  end

  def check!
    throw "No Database file: #{dbfile_path}" unless dbfile_path.exist?
  end

  def reset
    @shelf = {}
  end

  def copy (type, src, dest)
    put_phase("Copy: #{type}")
    Dir.entries(src).each do
      |it|
      next if /\A\.+\Z/ === it
      copy_files(type, src, dest, P(it))
    end
  end

  def copy_files (type, src, dest, shelf)
    shelfContents = @shelf[shelf.to_s] = []

    (src + shelf).entries.each do
      |book|
      next unless (src + shelf + book).file?
      next unless %w[epub pdf].include?(book.extname.downcase.sub(/\A\./, ''))
      put_now(book)
      src_file = src + shelf + book
      dest_file = PathUtil.escape_path(shelf + book).sub_ext('.kepub.epub')
      FileUtils.mkdir_p((dest + dest_file).parent)
      shelfContents << ShelfContent.new(type, dest_file)
      if copy_file(src_file, dest + dest_file)
        put_result('copied.')
      else
        put_result('skipped.')
      end
    end
  end

  def copy_file (src, dest)
    return false if dest.exist? and src.size == dest.size # and src.mtime == dest.mtime
    FileUtils.cp(src, dest)
    return true
  end

  def make_shelf_all
    dbfile = @body_path.join('.kobo', 'KoboReader.sqlite')

    SQLite3::Database.open(dbfile.to_s) do
      |db|
      db.results_as_hash = true

      @shelf.each do
        |name, contents|
        put_phase("Make Shelf: #{name}")
        make_shelf(db, name, contents)
      end
    end
  end

  def make_shelf (db, name, contents)
    if db.execute('select * from Shelf where Name = ?', name).empty?
      date = Time.now.getgm.strftime('%Y-%m-%dT%H:%M:%SZ')
      db.execute(
        'insert into Shelf' +
        '(CreationDate, InternalName, Name, _IsDeleted, _IsVisible, _IsSynced, LastModified)' +
        'values (?, ?, ?, "false", "true", "false", ?)',
        date, PathUtil.escape(name), name, date
      )
    end

    contents.each do
      |content|
      base = case content.type
             when :sd
               '/mnt/sd'
             else
               '/mnt/onboard'
             end
      id = 'file://' + (P(base) + content.id).to_s
      if db.execute('select * from ShelfContent where ContentId = ?', id).empty?
        db.execute(<<-EOM, name, id)
          insert into ShelfContent (ShelfName, ContentId) values (?, ?)
        EOM
      end
    end
  end

  def put_phase (name)
    STDOUT.puts("[#{name}]")
  end

  def put_now (name)
    STDOUT.puts(" -> #{name}")
  end

  def put_result (name)
    STDOUT.puts(" => #{name}")
  end
end

def P (path)
  if Pathname === path
    path
  else
    Pathname.new(path.to_s)
  end
end

class OptionParser
  def self.parse (args)
    require 'ostruct'
    require 'optparse'

    op = OpenStruct.new

    parser = OptionParser.new do
      |parser|
      parser.banner = "Usage: #{File.basename($0)} [options]"

      parser.on('--body <BODY_DRIVE_PATH>') { |it| op.body = P(it) }
      parser.on('--sd <SD_DRIVE_PATH>') { |it| op.sd = P(it) }
      parser.on('--body-source <BODY_SYNC_source>') { |it| op.body_source = P(it) }
      parser.on('--sd-source <SD_SYNC_source>') { |it| op.sd_source = P(it) }
    end

    parser.parse!(args)

    raise unless op.body and (op.body_source or (op.sd and op.sd_source))

    op
  rescue => e
    puts e
    puts parser.help
    exit
  end
end

options = OptionParser.parse(ARGV)
proj = Project.new
proj.body_path = options.body
proj.sd_path = options.sd
proj.body_source_path = options.body_source
proj.sd_source_path = options.sd_source
proj.run
