source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in qa_server.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec
# gem 'qa', github: 'samvera/questioning_authority', branch: 'min_context'

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use a debugger
# gem 'byebug', group: [:development, :test]

# rubocop:disable Bundler/DuplicatedGem
# BEGIN ENGINE_CART BLOCK
# engine_cart: 1.1.0
# engine_cart stanza: 0.10.0
# the below comes from engine_cart, a gem used to test this Rails engine gem in the context of a Rails app.
file = File.expand_path('Gemfile', ENV['ENGINE_CART_DESTINATION'] || ENV['RAILS_ROOT'] || File.expand_path('.internal_test_app', File.dirname(__FILE__)))
if File.exist?(file)
  begin
    eval_gemfile file
  rescue Bundler::GemfileError => e
    Bundler.ui.warn '[EngineCart] Skipping Rails application dependencies:'
    Bundler.ui.warn e.message
  end
else
  Bundler.ui.warn "[EngineCart] Unable to find test application dependencies in #{file}, using placeholder dependencies"

  if ENV['RAILS_VERSION']
    if ENV['RAILS_VERSION'] == 'edge'
      gem 'rails', github: 'rails/rails'
      ENV['ENGINE_CART_RAILS_OPTIONS'] = '--edge --skip-turbolinks'
    else
      gem 'rails', ENV['RAILS_VERSION']
    end
  end

  case ENV['RAILS_VERSION']
  when /^4.2/
    gem 'coffee-rails', '~> 4.1.0'
    gem 'responders', '~> 2.0'
    gem 'sass-rails', '5.1.6'
  when /^4.[01]/
    gem 'sass-rails', '5.1.6'
  end
end
# END ENGINE_CART BLOCK
# rubocop:enable Bundler/DuplicatedGem

eval_gemfile File.expand_path('spec/test_app_templates/Gemfile.extra', File.dirname(__FILE__)) unless File.exist?(file)
