# Adobe Experience Platform Consent Mobile Extension

## About this project

The AEP Consent Mobile Extension is an extension for the [Adobe Experience Platform SDK](https://github.com/Adobe-Marketing-Cloud/acp-sdks) and requires the `AEPCore`, and `AEPServices` extensions.

## Requirements
- Xcode 11.0 (or newer)
- Swift 5.1 (or newer)

## Installation

These are currently the supported installation options:

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

```ruby
# Podfile
use_frameworks!

# for app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPConsent'
    pod 'AEPEdge'
  	pod 'AEPCore'
  	pod 'AEPIdentity'
end

# for extension development, include AEPCore, AEPEdge, AEPConsent, and their dependencies
target 'YOUR_TARGET_NAME' do
    pod 'AEPConsent'
    pod 'AEPEdge'
  	pod 'AEPCore'
end
```

Replace `YOUR_TARGET_NAME` and then, in the `Podfile` directory, type:

```ruby
$ pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPConsent Package to your application, from the Xcode menu select:

`File > Swift Packages > Add Package Dependency...`

Enter the URL for the AEPConsent package repository: `https://github.com/adobe/aepsdk-consentedge-ios.git`.

When prompted, make sure you change the branch to `main`. (Once the repo is public, we will reference specific tags/versions instead of a branch)

Alternatively, if your project has a `Package.swift` file, you can add AEPConsent directly to your dependencies:

```
dependencies: [
	.package(url: "https://github.com/adobe/aepsdk-consentedge-ios.git", .branch: "main"),
targets: [
   	.target(name: "YourTarget",
    				dependencies: ["AEPConsent"],
          	path: "your/path"),
    ]
]
```

### Binaries

To generate an `AEPConsent.xcframework`, run the following command:

```ruby
$ make archive
```

This generates the xcframework under the `build` folder. Drag and drop all the `.xcframeworks` to your app target in Xcode.

## Development

The first time you clone or download the project, you should run the following from the root directory to setup the environment:

~~~
make pod-install
~~~

Subsequently, you can make sure your environment is updated by running the following:

~~~
make pod-update
~~~

#### Open the Xcode workspace
Open the workspace in Xcode by running the following command from the root directory of the repository:

~~~
make open
~~~

#### Command line integration

You can run all the test suites from command line:

~~~
make test
~~~

## Related Projects

| Project                                                      | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [AEPCore Extensions](https://github.com/adobe/aepsdk-core-ios) | The AEPCore, AEPServices and AEPIdentity represent the foundation of the Adobe Experience Platform SDK. |
| [AEPEdge Extension](https://github.com/adobe/aepsdk-edge-ios) | The AEPEdge extension allows you to send data to the Adobe Experience Platform (AEP) from a mobile application. |
| [AEP SDK Sample App for iOS](https://github.com/adobe/aepsdk-sample-app-ios) | Contains iOS sample apps for the AEP SDK. Apps are provided for both Objective-C and Swift implementations. |
| [AEP SDK Sample App for Android](https://github.com/adobe/aepsdk-sample-app-android) | Contains Android sample app for the AEP SDK.                 |
## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.
