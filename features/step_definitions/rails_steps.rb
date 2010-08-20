PROJECT_ROOT  = File.expand_path(File.join(File.dirname(__FILE__), '..', '..')).freeze
TEMP_ROOT     = File.join(PROJECT_ROOT, 'tmp').freeze
APP_NAME      = 'testapp'.freeze
RAILS_ROOT    = File.join(TEMP_ROOT, APP_NAME).freeze
TEMPLATE_ROOT = File.join(PROJECT_ROOT, 'features', 'templates').freeze
RAILS_VERSION = ENV['RAILS_VERSION'] || '2.3.8'

Before do
  FileUtils.rm_rf(TEMP_ROOT)
  FileUtils.mkdir_p(TEMP_ROOT)
  @terminal = Terminal.new
end

module RailsHelpers
  def rails2?
    RAILS_VERSION =~ /^2\./
  end
end

World(RailsHelpers)

When /^I save the following as "([^\"]*)"$/ do |path, string|
  string_with_version = string.gsub('{RAILS_VERSION}', RAILS_VERSION)
  FileUtils.mkdir_p(File.join(RAILS_ROOT, File.dirname(path)))
  File.open(File.join(RAILS_ROOT, path), 'w') { |file| file.write(string_with_version) }
end

When /^I run "([^\"]*)"$/ do |command|
  @terminal.cd(RAILS_ROOT)
  @terminal.run(command)
end

Then /^I should see "([^\"]*)"$/ do |expected_text|
  steps %{
    Then I should see:
    """
    #{expected_text}
    """
  }
end

Then /^I should see:$/ do |expected_text|
  unless @terminal.output.include?(expected_text)
    raise("Got terminal output:\n#{@terminal.output}\n\nExpected output:\n#{expected_text}")
  end
end

When /^I request "([^"]*)"$/ do |path|
  FileUtils.mkdir_p(File.join(RAILS_ROOT, 'script'))
  if rails2?
    FileUtils.cp(File.join(TEMPLATE_ROOT, 'rails2_request.template'),
                 File.join(RAILS_ROOT, 'script', 'request'))
  else
    FileUtils.cp(File.join(TEMPLATE_ROOT, 'rails3_request.template'),
                 File.join(RAILS_ROOT, 'script', 'request'))
  end
  @terminal.run("ruby script/request #{path}")
end

Then /^the following should be saved as "([^"]*)"$/ do |path, string|
  contents = IO.read(File.join(RAILS_ROOT, path))
  contents.strip.should == string.strip
end

When /^I configure the rails preinitializer to use bundler$/ do
  if rails2?
    FileUtils.cp(File.join(TEMPLATE_ROOT, 'preinitializer.rb.template'),
                 File.join(RAILS_ROOT, 'config', 'preinitializer.rb'))
    FileUtils.cp(File.join(TEMPLATE_ROOT, 'boot.rb.template'),
                 File.join(RAILS_ROOT, 'config', 'boot.rb'))
    FileUtils.ln_s(File.join(PROJECT_ROOT, 'generators'),
                   File.join(RAILS_ROOT, 'lib', 'generators'))
  end
end

When /^I generate a new rails application$/ do
  @terminal.cd(TEMP_ROOT)
  if rails2?
    @terminal.run("rails _#{RAILS_VERSION}_ #{APP_NAME}")
  else
    @terminal.run("rails _#{RAILS_VERSION}_ new #{APP_NAME}")

    config_path = File.join(RAILS_ROOT, 'config', 'application.rb')
    config = IO.read(config_path)
    replace = "class Application < Rails::Application"
    new_config = <<-RUBY
      config.middleware.delete ActionDispatch::ShowExceptions
    RUBY
    config.gsub!(replace, "#{replace}\n#{new_config}")
    File.open(config_path, 'w') { |file| file.write(config) }
  end
end

When /^I configure my routes to allow global access$/ do
  unless rails2?
    steps %{
      When I save the following as "config/routes.rb"
        """
        Testapp::Application.routes.draw do
          match ':controller(/:action(/:id(.:format)))'
        end
        """
    }
  end
end
