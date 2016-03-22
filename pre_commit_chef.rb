#!/usr/bin/env ruby

require 'english'
puts 'requirements loaded'
exitflag = 0

lint_checkers = {
  'foodcritic' => {
    'name'              => 'foodcritic',
    'manual_install'    => 'gem install foodcritic --no-ri --no-rdoc',
    'automated_install' => 'yes | gem install foodcritic --no-ri --no-rdoc',
    'check_command'     => 'foodcritic -V >/dev/null 2>&1',
    'extension'         => 'rb'
  },
  'rubocop' => {
    'name'              => 'rubocop',
    'manual_install'    => 'gem install rubocop',
    'automated_install' => 'yes | gem install rubocop --no-ri --no-rdoc',
    'check_command'     => 'rubocop -s >/dev/null 2>&1',
    'extension'         => 'rb'
  },
  'shellcheck' => {
    'name'              => 'shellcheck',
    'manual_install'    => 'brew install shellcheck',
    'automated_install' => 'yes | brew install shellcheck',
    'check_command'     => 'which shellcheck >/dev/null 2>&1',
    'extension'         => 'sh'
  }
}

# Check the lint checkers and install if needed
lint_checkers.each do |_check, params|
  puts "running #{params['check_command']}"
  system "#{params['check_command']}"
  unless $CHILD_STATUS.success?
    puts "#{params['check_command']} NOT found... installing..."
    exec "#{params['automated_install']}"
    unless $CHILD_STATUS.success?
      puts "#{params['name']} installation failure, please try"
      puts "  #{params['manual_install']}"
      puts 'to resolve'
      exitflag = 1
    end
  end
end

# Get the names of (A)dded, (C)opied, (M)odified files
STAGED_FILES = `git diff-index --name-only --diff-filter=ACM HEAD`

# Iterate over the list and run each relevant lint check
STAGED_FILES.lines do |file|
  file.chomp! # remove carriage returns
  lint_checkers.each do |_check, params|
    if file =~ /#{params['extension']}/
      puts "  #{params['name']} validating file: #{file}"
      lint_check_output = "#{params['name']} #{file}"
      unless $CHILD_STATUS.success?
        puts lint_check_output
        exitflag = 1
      end
    end
  end
end

# Individual checks
COOKBOOK_PATH = File.split `git rev-parse --show-toplevel`
PARENT_PATH = COOKBOOK_PATH[0]
COOKBOOK_NAME = COOKBOOK_PATH[1].chomp # remove trailing newline

# check for whitespace errors
git_ws_check = `git diff-index --check --cached HEAD --`
unless $CHILD_STATUS.success?
  puts git_ws_check
  exitflag = 1
end

puts 'Running knife...'
knife_output = `knife cookbook test #{ COOKBOOK_NAME } -o #{ PARENT_PATH } -c ~/.chef/knife.rb 2>&1`
unless $CHILD_STATUS.success?
  puts knife_output
  exitflag = 1
end

fc_output = `foodcritic --epic-fail any #{ File.join(PARENT_PATH, COOKBOOK_NAME) }`
unless $CHILD_STATUS.success?
  puts "  #{fc_output}"
  exitflag = 1
end

exit 1 if exitflag == 1
