# frozen_string_literal: true

require_relative 'utils/shell'

namespace :lint do
  desc 'Run Ruby linter'
  task :ruby do
    cmd = ['rubocop']
    cmd << '--autocorrect' if ENV['FIX']
    Shell.run(cmd)
  end

  desc 'Run ERB linter'
  task :erb do
    cmd = ['erb_lint']
    cmd << '--autocorrect' if ENV['FIX']
    cmd.push('**/*.erb')
    Shell.run(cmd)
  end

  desc 'Run JavaScript linter'
  task :js do
    if ENV['CONTAINER']
      puts 'The npm ci command may take a while, be patient!'.magenta
      lint_args = ENV['FIX'] ? '-- --fix' : ''
      Shell.run(['docker', 'run', '--rm', '-v', "#{Dir.pwd}:/code", '-w', '/code',
                 'node:20', 'sh', '-c', "npm ci --legacy-peer-deps --loglevel=error && npm run lint #{lint_args}"])
    else
      cmd = ['npm', 'run', 'lint']
      cmd.push('--', '--fix') if ENV['FIX']
      Shell.run(cmd)
    end
  end
end

desc 'Run all linters'
task lint: ['lint:ruby', 'lint:erb', 'lint:js']

desc 'Run all linters and apply fixes'
task 'lint:fix' do
  ENV['FIX'] = 'true'
  Rake::Task['lint'].invoke
end
