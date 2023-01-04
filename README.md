# Soto Code Generator

The Code Generator for Soto, generating Swift client code for AWS using the Smithy models provided by AWS.

## Build plugin

The Soto repository is very large and in general most projects only need a few of the many services it supports. To avoid having to download the full project we have built a Swift Package Manager Build Plugin which adds the conversion from Smithy model file to Swift into your build process. 

### Setup

Replace your dependency on Soto in the Package.swift with the following

```swift
.package(url: "https://github.com/soto-project/soto-codegenerator", from: "0.6.0"),
.package(url: "https://github.com/soto-project/soto-core.git", from: "6.4.0")
```

And the target you want to add the generated Soto code to should be setup as follows
```swift
.target(
    name: "MySotoServices",
    dependencies: [.product(name: "SotoCore", package: "soto-core")],
    plugins: [.plugin(name: "SotoCodeGeneratorPlugin", package: "soto-codegenerator")]
)
```

You need a couple of files from the Soto repository. 
- The region endpoint definition file [endpoints.json](https://github.com/soto-project/soto/blob/main/models/endpoints/endpoints.json)
- The model file for the service you want to use. You can find these [here](https://github.com/soto-project/soto/blob/main/models/). 

The Build Plugin will search for the `endpoints.json` first in the root of your target and then the root of your project. The model file should be added to your target. Unless you are using a new region endpoint or new functionality from a service you shouldn't need to update these again.

If your target only includes AWS Smithy model files in it, you need to add a dummy empty Swift file to the folder. Otherwise the Swift Package Manager will warn you have no source files for your target and not build the target. 

Now when you build your target
```
swift build
```
The build plugin will put the generated Swift code in `.build/plugins/outputs/<package name>/<target name>/SotoCodeGeneratorPlugin/GeneratedSources` and will include it in the list of Swift files for that target.

### Missing Code

If you are dependent on extension code from Soto (eg S3 multipart upload, STS/Cognito credential providers or DynamoDB Codable support), this process may not work for you as the extension code is not generated and will not be available to you.

## Config file

You can add a configuration file `soto.config.json` to your project to control the Swift code generation. 

Many of the services have a lot of operations which you may never use. If you are working in a low memory environment (eg an AWS Lambda or an iOS app)and only use `s3.getObject` why include code for the other 94 S3 operations in your code base. The configuration file can be used to filter the operations you generate code for. The following `soto.config.json` will only output code for `getObject`.

```json
{
    "services": { 
        "s3": {
            "operations": ["getObject"]
        }
    },
}
```

You can have multiple services listed under the `services` field. In this example `s3` is the service name and should be the same as the Smithy model file name the service is generated from, the list of operations need to be the same as the generated function name ie camel case with a lowercase first character.

If you don't want to have something as static as the `operations` field there is also the `access` field which is a global field that controls the access control for the generated code. This can be set to either `internal` or `public`.

```json
{
    "access": "internal"
}
```

Setting this to `internal` will set the access control for your code to `internal` and you'll only be able to use the generated code within the same target. The linker should then be able to remove any unused generated code. If you only use `s3.getObject` you'll only link the code for `s3.getObject`.

A sample project using the SotoCodeGenerator build plugin can be found [here](https://github.com/adam-fowler/soto-codegenerator-plugin-test).


