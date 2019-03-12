require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :build_web do
  Dir.chdir(File.join(File.dirname(__FILE__), "web"))
  sh("rm -Rf dist")
  sh("npm run build")
end

Rake::Task[:release].prerequisites.unshift(:build_web)

task :default => :test
