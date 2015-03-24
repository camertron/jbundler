load File.expand_path(File.join('spec', 'setup.rb'))
require 'jbundler/classpath_file'
require 'maven/tools/jarfile'
require 'jbundler/gemfile_lock'

describe JBundler::ClasspathFile do

  let(:workdir) { File.join('pkg', 'tmp') }
  let(:jfile) { File.join(workdir, 'jarfile') }
  let(:gfile_lock) { File.join(workdir, 'gemfile.lock') }
  let(:jfile_lock) { jfile + ".lock"}
  let(:cpfile) { File.join(workdir, 'cp.rb') }
  let(:jarfile) { Maven::Tools::Jarfile.new(jfile) }
  let(:gemfile_lock) { JBundler::GemfileLock.new(jarfile, gfile_lock) }
  subject { JBundler::ClasspathFile.new(cpfile) }

  before do
    FileUtils.mkdir_p(workdir)
    Dir[File.join(workdir, '*')].each { |f| FileUtils.rm_f f }
  end

  it 'needs no update when all files are missing' do
    subject.needs_update?(jarfile, gemfile_lock).must_equal false
  end

  it 'needs update when only gemfile' do
    FileUtils.touch gfile_lock
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'needs update when only jarfile' do
    FileUtils.touch jfile
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'needs update when jarfilelock is missing' do
    FileUtils.touch gfile_lock
    FileUtils.touch jfile
    FileUtils.touch cpfile
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'needs no update when classpath file is the youngest' do
    FileUtils.touch jfile
    FileUtils.touch jfile_lock
    FileUtils.touch cpfile
    subject.needs_update?(jarfile, gemfile_lock).must_equal false
  end

  it 'needs update when jar file is the youngest' do
    FileUtils.touch gfile_lock
    FileUtils.touch jfile_lock
    FileUtils.touch cpfile
    sleep 1
    FileUtils.touch jfile
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'needs update when jar lockfile is the youngest' do
    FileUtils.touch gfile_lock
    FileUtils.touch jfile
    FileUtils.touch cpfile
    sleep 1
    FileUtils.touch jfile_lock
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'needs update when gem lockfile is the youngest' do
    FileUtils.touch jfile
    FileUtils.touch cpfile
    FileUtils.touch jfile_lock
    sleep 1
    FileUtils.touch gfile_lock
    subject.needs_update?(jarfile, gemfile_lock).must_equal true
  end

  it 'generates a classpath ruby file without localrepo' do
    subject.generate("a:b:c:d:f:".split(File::PATH_SEPARATOR) )
    File.read(cpfile).must_equal <<-EOF
JBUNDLER_JRUBY_CLASSPATH = []
JBUNDLER_JRUBY_CLASSPATH.freeze
JBUNDLER_TEST_CLASSPATH = []
JBUNDLER_TEST_CLASSPATH.freeze
JBUNDLER_CLASSPATH = []
JBUNDLER_CLASSPATH << 'a'
JBUNDLER_CLASSPATH << 'b'
JBUNDLER_CLASSPATH << 'c'
JBUNDLER_CLASSPATH << 'd'
JBUNDLER_CLASSPATH << 'f'
JBUNDLER_CLASSPATH.freeze
EOF
  end

  it 'generates a classpath ruby file with localrepo' do
    subject.generate("a:b:c:d:f:".split(File::PATH_SEPARATOR), [], [], '/tmp')
    File.read(cpfile).must_equal <<-EOF
require 'jar_dependencies'
JBUNDLER_LOCAL_REPO = Jars.home
JBUNDLER_JRUBY_CLASSPATH = []
JBUNDLER_JRUBY_CLASSPATH.freeze
JBUNDLER_TEST_CLASSPATH = []
JBUNDLER_TEST_CLASSPATH.freeze
JBUNDLER_CLASSPATH = []
JBUNDLER_CLASSPATH << (JBUNDLER_LOCAL_REPO + 'a')
JBUNDLER_CLASSPATH << (JBUNDLER_LOCAL_REPO + 'b')
JBUNDLER_CLASSPATH << (JBUNDLER_LOCAL_REPO + 'c')
JBUNDLER_CLASSPATH << (JBUNDLER_LOCAL_REPO + 'd')
JBUNDLER_CLASSPATH << (JBUNDLER_LOCAL_REPO + 'f')
JBUNDLER_CLASSPATH.freeze
EOF
  end

  it 'require classpath using default with generated localrepo' do
    ENV[ 'JARS_HOME' ] = '/tmp'
    Jars.reset
    subject.generate("/a:/b:/c:/d:/f:".split(File::PATH_SEPARATOR), [], [], '/tmp')
    begin
      subject.require_classpath
    rescue LoadError
      # there are no files to require
    end
    JBUNDLER_CLASSPATH.must_equal ["/tmp/a", "/tmp/b", "/tmp/c", "/tmp/d", "/tmp/f"]
  end

  it 'require classpath with generated localrepo' do
    ENV[ 'JARS_HOME' ] = '/tmp'
    subject.generate("/a:/b:/c:/d:/f:".split(File::PATH_SEPARATOR), [], [], '/tmp')
    
    begin
      Jars.reset
      ENV[ 'JARS_HOME' ] = '/temp'
      subject.require_classpath
    rescue LoadError
      # there are no files to require
    end
    JBUNDLER_CLASSPATH.must_equal ["/temp/a", "/temp/b", "/temp/c", "/temp/d", "/temp/f"]
  end
end
