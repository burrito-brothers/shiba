require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/*_test.rb']
    t.verbose = true
  end

task :default => :test

task :build_web do
  Dir.chdir(File.join(File.dirname(__FILE__), "web"))
  sh("rm -Rf dist")
  sh("npm run build")
end

task :check_master do
  current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
  if "master" != current_branch
    $stderr.puts "\n===== Warning: Not on master. running on branch #{current_branch} =====\n\n"
  end
end

Rake::Task[:release].prerequisites.unshift(:check_master)
Rake::Task[:release].prerequisites.unshift(:build_web)

task :default => :test