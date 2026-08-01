Pod::Spec.new do |s|
  s.name = 'kelivo_durable_preferences'
  s.version = '0.1.0'
  s.summary = 'Kelivo Apple durable preferences implementation.'
  s.description = 'Kelivo-owned atomic preference storage for iOS and macOS.'
  s.homepage = 'https://github.com/BelovedYaoo/kelivo'
  s.license = { :type => 'AGPL-3.0-only', :text => 'SPDX-License-Identifier: AGPL-3.0-only' }
  s.author = { 'Kelivo' => 'kelivo@localhost' }
  s.source = { :path => '.' }
  s.source_files = 'kelivo_durable_preferences/Sources/kelivo_durable_preferences/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
  s.resource_bundles = {
    'kelivo_durable_preferences_privacy' => [
      'kelivo_durable_preferences/Sources/kelivo_durable_preferences/Resources/PrivacyInfo.xcprivacy'
    ]
  }
end
