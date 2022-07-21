# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

# Comment the next line if you don't want to use dynamic frameworks
use_frameworks!

workspace 'AEPEdgeConsent'
project 'AEPEdgeConsent.xcodeproj'

pod 'SwiftLint', '0.44.0'

target 'AEPEdgeConsent' do
  pod 'AEPCore'
  pod 'AEPServices'
end

target 'UnitTests' do
  pod 'AEPCore'
  pod 'AEPServices'
end

target 'FunctionalTests' do
  pod 'AEPCore'
  pod 'AEPServices'
end

target 'TestAppSwift' do
  pod 'AEPCore'
  pod 'AEPServices'
end

target 'TestAppSwifttvOS' do
  pod 'AEPCore'
  pod 'AEPServices'
end

target 'TestAppObjc' do
  pod 'AEPCore'
  pod 'AEPServices'
end

post_install do |pi|
  pi.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
        bc.build_settings['TVOS_DEPLOYMENT_TARGET'] = '10.0'
        bc.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator appletvos appletvsimulator'
        bc.build_settings['TARGETED_DEVICE_FAMILY'] = "1,2,3"
    end
  end
end
