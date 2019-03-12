require_relative 'helper'
require 'shiba/review/cli'

describe "Review" do
  let(:memout)  { StringIO.new }
  let(:memerr)  { StringIO.new }
  let(:memin)   { StringIO.new }
  let(:cli)     { Shiba::Review::CLI.new(out: memout, err: memerr, stdin: memin, options: options) }
  let(:options) { Hash.new }

  describe "with the raw option" do
    it "prints the raw explains for problems when enabled" do
      options["raw"]     = true
      options["file"]    = "test/data/ci.json"

      status, out, err = run_cli(cli)
      status = cli.run
      assert_equal 2, status, "Wrong status. err: #{err}, out: #{out}"

      problems = File.read(options["file"]).lines.select { |line| !line.include?('"severity":"none"') }
      assert_equal 1, problems.size # this will fail whenever the ci.json test file adds more problems
      problems = problems.join("\n")
      assert problems == out, "Output does not match. expected: #{problems.inspect},\n\noutput: #{out.inspect}"
    end

    it "is able to comment on its own output" do
      options["raw"]     = true
      options["file"]    = "test/data/ci.json"
      status, out, _ = run_cli(cli)
      assert_equal 2, status

      cli2 = Shiba::Review::CLI.new(out: memout, err: memerr, stdin: memin, options: {})
      memin.puts out
      status, out, err = run_cli(cli2)
      assert_equal 2, status, "Wrong status. err: #{err}, out: #{out}"
      assert_equal "", err

      comments = <<-EOF
        SELECT `users`.* FROM `users` WHERE `users`.`email` = 'squirrel@example.com':-2 ()
        Table Scan: The database reads 100% (100000) of the of the rows in **users**, skipping any indexes.
        Results: The database returns 4.4mb (100000 rows) to the client.
        Estimated query time: 1.74s
      EOF
      comments = comments.split("\n").map(&:strip).join("\n")
      comments << "\n\n"

      assert_equal comments, out, out.inspect
    end

    it "includes the PR number when available" do
      options["raw"]          = true
      options["file"]         = "test/data/ci.json"
      options["pull_request"] = "5"
      status, out, err = run_cli(cli)
      assert_equal 2, status, "Wrong status. err: #{err}, out: #{out}"

      json = JSON.parse(out.lines.first)
      assert_equal "5", json["pull_request"], json.inspect
    end
  end

  def run_cli(cli)
    r = cli.run
    cli.err.rewind
    cli.out.rewind
    out = cli.out.read
    err = cli.err.read
    cli.err.reopen
    cli.out.reopen

    return r, out, err
  end

end