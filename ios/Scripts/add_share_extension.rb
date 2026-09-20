#!/usr/bin/env ruby
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Adds the ShareExtension target to ios/Runner.xcodeproj. This script was run
# once, for WP-24, and its result is committed. It stays in the repository so
# that the change to project.pbxproj can be read and reproduced: after
# `flutter create .` has regenerated the project, say, or to check that the
# committed project file is what this script makes of the one before it.
#
#   gem install --user-install xcodeproj -v 1.27.0   # macOS system Ruby is enough
#   ruby ios/Scripts/add_share_extension.rb
#
# (1.27.0, because later versions pull in a native extension that the system
# Ruby of current macOS versions cannot compile.)
#
# The script refuses to run when the target exists. New objects get the ids
# BC24000000000000000000NN in the order they are created, so two runs on the
# same input give the same file. Saving through xcodeproj also sorts each
# section of the file by id, which moves the hand-made BC01... and BC23...
# lines of earlier work packages to the end of their sections, and shortens one
# comment, which the last lines of this script restore. Nothing more.
#
# What it adds:
#   - file references: three xcconfig files in Config, the ShareExtension
#     group, SharedPgnInbox.swift (Runner) and SharedPgnInboxTests.swift
#     (RunnerTests);
#   - the target ShareExtension (an app extension; Sources, Frameworks and
#     Resources phases) with Debug, Release and Profile configurations that
#     have a base configuration and NO build settings: those are all in
#     ios/Config/ShareExtension*.xcconfig;
#   - in the Runner target: a dependency on the extension and the copy phase
#     "Embed Foundation Extensions" (destination PlugIns), placed FIRST. After
#     Flutter's "Thin Binary" script phase Xcode reports a dependency cycle;
#     docs.flutter.dev/platform-integration/ios/app-extensions says to put it
#     above "Run Script".

require 'xcodeproj'

TARGET_NAME = 'ShareExtension'
project_path = File.expand_path('../Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

abort "#{TARGET_NAME} exists already, nothing to do." if project.targets.any? { |t| t.name == TARGET_NAME }

# Deterministic ids instead of random ones.
counter = 0
project.define_singleton_method(:generate_uuid) do
  counter += 1
  format('BC24%020d', counter)
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

# --- file references ---------------------------------------------------------

config_group = group_at(project, 'Config')
xcconfig = {}
%w[ShareExtension ShareExtension-Debug ShareExtension-Release].each do |name|
  xcconfig[name] = add_file(config_group, "#{name}.xcconfig", 'text.xcconfig')
end

inbox = add_file(group_at(project, 'Runner'), 'SharedPgnInbox.swift', 'sourcecode.swift')
runner.source_build_phase.add_file_reference(inbox)

inbox_tests = add_file(group_at(project, 'RunnerTests'), 'SharedPgnInboxTests.swift', 'sourcecode.swift')
runner_tests.source_build_phase.add_file_reference(inbox_tests)

extension_group = project.main_group.new_group(TARGET_NAME, TARGET_NAME)
# After Runner, before Products.
project.main_group.children.move(extension_group, project.main_group.children.index(group_at(project, 'Runner')) + 1)
controller = add_file(extension_group, 'ShareViewController.swift', 'sourcecode.swift')
add_file(extension_group, 'Info.plist', 'text.plist.xml')
add_file(extension_group, 'ShareExtension.entitlements', 'text.plist.entitlements')
privacy = add_file(extension_group, 'PrivacyInfo.xcprivacy', 'text.xml')

# --- the target --------------------------------------------------------------

Obj = Xcodeproj::Project::Object

target = project.new(Obj::PBXNativeTarget)
target.name = TARGET_NAME
target.product_name = TARGET_NAME
target.product_type = 'com.apple.product-type.app-extension'
project.targets << target

product = project.products_group.new_reference("#{TARGET_NAME}.appex", :built_products)
product.explicit_file_type = 'wrapper.app-extension'
product.last_known_file_type = nil
product.include_in_index = '0'
target.product_reference = product

configurations = project.new(Obj::XCConfigurationList)
configurations.default_configuration_is_visible = '0'
configurations.default_configuration_name = 'Release'
{ 'Debug' => 'ShareExtension-Debug', 'Release' => 'ShareExtension-Release',
  'Profile' => 'ShareExtension-Release' }.each do |name, base|
  configuration = project.new(Obj::XCBuildConfiguration)
  configuration.name = name
  configuration.base_configuration_reference = xcconfig[base]
  configuration.build_settings = {}
  configurations.build_configurations << configuration
end
target.build_configuration_list = configurations

sources = project.new(Obj::PBXSourcesBuildPhase)
frameworks = project.new(Obj::PBXFrameworksBuildPhase)
resources = project.new(Obj::PBXResourcesBuildPhase)
[sources, frameworks, resources].each { |phase| target.build_phases << phase }
sources.add_file_reference(controller)
resources.add_file_reference(privacy)

attributes = project.root_object.attributes
attributes['TargetAttributes'] ||= {}
attributes['TargetAttributes'][target.uuid] = { 'CreatedOnToolsVersion' => '27.0' }
project.root_object.attributes = attributes

# --- embedded in Runner ------------------------------------------------------

runner.add_dependency(target)

embed = project.new(Obj::PBXCopyFilesBuildPhase)
embed.name = 'Embed Foundation Extensions'
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
build_file = embed.add_file_reference(product)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.build_phases.insert(0, embed)

project.save

# xcodeproj shortens the comment next to the local Swift package reference.
# Flutter's project migrations look for the original text, so put it back.
pbxproj = File.join(project_path, 'project.pbxproj')
text = File.read(pbxproj)
text.gsub!('/* XCLocalSwiftPackageReference "FlutterGeneratedPluginSwiftPackage" */',
           '/* XCLocalSwiftPackageReference "Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */')
File.write(pbxproj, text)

puts "Added #{TARGET_NAME} (#{counter} new objects)."
