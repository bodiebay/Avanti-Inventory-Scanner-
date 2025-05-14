#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main Runner target
runner_target = project.targets.find { |t| t.name == 'Runner' }

if runner_target
  runner_target.build_configurations.each do |config|
    # Remove the -framework Pods_Runner flag
    if config.build_settings['OTHER_LDFLAGS']
      flags = config.build_settings['OTHER_LDFLAGS']
      flags.delete('-framework')
      flags.delete('Pods_Runner')
      config.build_settings['OTHER_LDFLAGS'] = flags
    end
  end
  
  # Save changes
  project.save
  puts "Successfully modified Runner.xcodeproj to remove -framework Pods_Runner"
else
  puts "Could not find Runner target"
end
