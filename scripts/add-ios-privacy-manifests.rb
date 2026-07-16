#!/usr/bin/env ruby
require 'fileutils'
require 'xcodeproj'

pods_root = File.expand_path('../ios/App/Pods', __dir__)
project_path = File.join(pods_root, 'Pods.xcodeproj')
abort "Pods project not found: #{project_path}" unless File.exist?(project_path)

manifest = <<~PLIST
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>NSPrivacyTracking</key><false/>
    <key>NSPrivacyTrackingDomains</key><array/>
    <key>NSPrivacyCollectedDataTypes</key><array/>
    <key>NSPrivacyAccessedAPITypes</key><array/>
  </dict></plist>
PLIST

project = Xcodeproj::Project.open(project_path)
targets = project.targets.select { |target| target.name == 'GoogleToolboxForMac' }
abort 'GoogleToolboxForMac target not found in Pods project' if targets.empty?
privacy_dir = File.join(pods_root, 'GoogleToolboxForMac', 'Privacy')
privacy_file = File.join(privacy_dir, 'PrivacyInfo.xcprivacy')
FileUtils.mkdir_p(privacy_dir)
File.write(privacy_file, manifest)
group = project.main_group.find_subpath('Privacy Manifests/GoogleToolboxForMac', true)
file_ref = group.files.find { |file| file.path == privacy_file } || group.new_file(privacy_file)
targets.each do |target|
  target.resources_build_phase.add_file_reference(file_ref, true) unless target.resources_build_phase.files_references.include?(file_ref)
end
project.save
puts 'Added PrivacyInfo.xcprivacy to GoogleToolboxForMac framework resources'
