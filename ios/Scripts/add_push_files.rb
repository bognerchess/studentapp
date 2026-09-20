#!/usr/bin/env ruby
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Adds the files of WP-32 (push notifications) to ios/Runner.xcodeproj. Run
# once; the result is committed. Kept for the same reason as
# add_share_extension.rb: so that the change to project.pbxproj can be read
# and repeated.
#
#   gem install --user-install xcodeproj -v 1.27.0
#   ruby ios/Scripts/add_push_files.rb
#
# What it adds, with the ids BC32000000000000000000NN:
#   - Runner/PushHandler.swift to the sources of Runner;
#   - RunnerTests/PushHandlerTests.swift to the sources of RunnerTests;
#   - Runner/{en,de}.lproj/Localizable.strings as one variant group in the
#     resources of Runner (the texts of loc-key pushes). Both regions are
#     known regions of the project already.

require 'xcodeproj'

project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

abort 'PushHandler.swift is in the project already, nothing to do.' if
  project.files.any? { |f| f.path == 'PushHandler.swift' }

counter = 0
project.define_singleton_method(:generate_uuid) do
  counter += 1
  format('BC32%020d', counter)
end

def group_at(project, path)
  project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.path == path } ||
    abort("group #{path} not found")
end

def add_file(group, name, type)
  ref = group.new_reference(name)
  ref.last_known_file_type = type
  ref.include_in_index = nil
  ref
end

runner = project.targets.find { |t| t.name == 'Runner' } || abort('no Runner target')
runner_tests = project.targets.find { |t| t.name == 'RunnerTests' } || abort('no RunnerTests target')
runner_group = group_at(project, 'Runner')

handler = add_file(runner_group, 'PushHandler.swift', 'sourcecode.swift')
runner.source_build_phase.add_file_reference(handler)

tests = add_file(group_at(project, 'RunnerTests'), 'PushHandlerTests.swift', 'sourcecode.swift')
runner_tests.source_build_phase.add_file_reference(tests)

strings = runner_group.new_variant_group('Localizable.strings')
%w[en de].each do |region|
  ref = strings.new_reference("#{region}.lproj/Localizable.strings")
  ref.name = region
  ref.last_known_file_type = 'text.plist.strings'
  ref.include_in_index = nil
end
runner.resources_build_phase.add_file_reference(strings)

project.save

# As in add_share_extension.rb: Flutter's migrations look for the long form.
pbxproj = File.join(project_path, 'project.pbxproj')
text = File.read(pbxproj)
text.gsub!('/* XCLocalSwiftPackageReference "FlutterGeneratedPluginSwiftPackage" */',
           '/* XCLocalSwiftPackageReference "Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */')
File.write(pbxproj, text)

puts "Added the push files (#{counter} new objects)."
