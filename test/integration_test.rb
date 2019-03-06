require_relative 'helper'
require 'shiba'
require 'shiba/fuzzer'
require 'shiba/configure'
require 'open3'
require 'tempfile'

module IntegrationTest

  describe "Connection" do
    it "doesn't blow up" do
      function = Shiba.connection.mysql? ? "database" : "current_database"
      assert_equal Shiba.database, Shiba.connection.query("select #{function}() as db").first["db"]

      stats = Shiba::Fuzzer.new(Shiba.connection).fuzz!
      assert stats.any?, stats.inspect
    end

    it "logs queries" do
      begin
        file = Tempfile.new('integration_test_log_queries')
        test_app_path = File.join(File.dirname(__FILE__), 'app', 'app.rb')

        # Note: log file is auto-removed. Use debugger to debug output issues.
        env = { 'SHIBA_PATH' => File.dirname(file.path), 'SHIBA_OUT' => File.basename(file.path)}
        run_command(env, "ruby", test_app_path)

        queries = File.read(file.path)
        # Should be 1, but there's schema loading garbage that's hard to remove
        assert_equal 3, queries.lines.size, "No queries logged, got:\n#{queries.inspect}"
      ensure
        file.close
        file.unlink
      end
    end

    it "logs queries on CI" do
      skip if !Shiba::Configure.ci?
      test_app_path = File.join(File.dirname(__FILE__), 'app', 'app.rb')

      out,_ = run_command({}, "ruby", test_app_path)

      assert File.exist?(File.join(Shiba.path, 'ci.json')), "Failed. Specify CI=true to replicate locally.\nNo ci log file found at #{Shiba.path}, got\n #{out}"
    end

    it "reviews queries" do
      file = Tempfile.new('integration_test_log_queries')
      test_app_path = File.join(File.dirname(__FILE__), 'app', 'app.rb')

      env = { 'SHIBA_PATH' => File.dirname(file.path), 'SHIBA_OUT' => File.basename(file.path)}
      out, status = run_command(env, "ruby", test_app_path)
      assert_equal 0, status, "Expected exit status 0, got #{status}\n#{out}"

      # Note: log file is auto-removed. Use debugger to debug output issues.
      bin = File.join(Shiba.root, "bin/review")
      env.merge!('DIFF' => "test/data/test_app.diff")

      out, status = run_command(env, bin, "-f#{file.path}.json")

      assert_equal 2, status, "Expected exit status 2, got #{status}\n. Backtrace: #{out.join}"
      assert_match(/Table Scan/, out.join)
      assert_match(/reads 100%/, out.join)
    end
  end

end

def run_command(env, *argv)
  out    = nil
  thread = nil
  Open3.popen2e(env, *argv) {|_,eo,th|
    out = eo.readlines
    thread = th
    if ENV['SHIBA_DEBUG']
      $stderr.puts out
    end
  }

  return out, thread.value.exitstatus
end
