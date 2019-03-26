
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shiba/version"

Gem::Specification.new do |spec|
  spec.name          = "shiba"
  spec.version       = Shiba::VERSION
  spec.authors       = ["Ben Osheroff", "Eric Chapweske"]
  spec.email         = ["ben@gimbo.net", "ben.osheroff@gmail.com", "ericis@gmail.com"]

  spec.summary       = %q{Catch bad SQL queries before they cause problems in production}
  spec.description   = %q{Use production statistics for realistic SQL query analysis. Finds code that may take down production, including missing indexes, overly broad indexes, and queries that return too much data.
  }
  spec.homepage      = "https://github.com/burrito-brothers/shiba"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    #spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
    #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(data|test|spec|features)/}) }
  end

  spec.files        += Dir.glob(File.join("web", "dist", "**/**"))
  spec.bindir        = "bin"
  spec.executables   = ["shiba"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
end
