#!/bin/bash
#
# Copyright 2021 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

PROJECT_NAME=TestProject

# Clean up.
rm -rf $PROJECT_NAME

mkdir -p $PROJECT_NAME && cd $PROJECT_NAME

# Create a new Xcode project.
swift package init

# Use Xcodegen to generate the project.
echo "
name: $PROJECT_NAME
options:
  bundleIdPrefix: $PROJECT_NAME
targets:
  $PROJECT_NAME:
    type: framework
    sources: Sources
    platform: iOS
    deploymentTarget: "12.0"
    settings:
      GENERATE_INFOPLIST_FILE: YES
" >>project.yml

xcodegen generate

# Create a Podfile with our pod as dependency.
echo "
platform :ios, '12.0'
target '$PROJECT_NAME' do
  use_frameworks!
  pod 'AEPCore', '~> 5.0'
  pod 'AEPServices', '~> 5.0'
  pod 'AEPRulesEngine', '~> 5.0'
  pod 'AEPEdge', '~> 5.0'
  pod 'AEPEdgeConsent', :path => '../AEPEdgeConsent.podspec'
end
" >>Podfile

# Install the pods.
pod install

# Archive for generic iOS device
echo '############# Archive for generic iOS device ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS'

# Build for generic iOS device
echo '############# Build for generic iOS device ###############'
xcodebuild clean build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS'

# Archive for x86_64 iOS simulator
echo '############# Archive for iOS simulator ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS Simulator'

# Build for x86_64 iOS simulator
echo '############# Build for iOS simulator ###############'
xcodebuild clean build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS Simulator'

# Clean up.
cd ../
rm -rf $PROJECT_NAME

# tvOS
mkdir -p $PROJECT_NAME && cd $PROJECT_NAME
# Create a new Xcode project.
swift package init

# Use Xcodegen to generate the project.
echo "
name: $PROJECT_NAME
options:
  bundleIdPrefix: $PROJECT_NAME
targets:
  $PROJECT_NAME:
    type: framework
    sources: Sources
    platform: tvOS
    deploymentTarget: "12.0"
    settings:
      GENERATE_INFOPLIST_FILE: YES
" >>project.yml

xcodegen generate

# Create a Podfile with our pod as dependency.
echo "
platform :tvos, '12.0'
target '$PROJECT_NAME' do
  use_frameworks!
  pod 'AEPCore', '~> 5.0'
  pod 'AEPServices', '~> 5.0'
  pod 'AEPRulesEngine', '~> 5.0'
  pod 'AEPEdge', '~> 5.0'
  pod 'AEPEdgeConsent', :path => '../AEPEdgeConsent.podspec'
end
" >>Podfile

# Install the pods.
pod install
# Archive for generic tvOS device
echo '############# Archive for generic tvOS device ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS'

# Build for generic tvOS device
echo '############# Build for generic tvOS device ###############'
xcodebuild build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS'

# Archive for generic tvOS device
echo '############# Archive for generic tvOS device ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS Simulator'

# Build for generic tvOS simulator
echo '############# Build for x86_64 tvOS simulator ###############'
xcodebuild build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS Simulator'

# Clean up.
cd ../
rm -rf $PROJECT_NAME
