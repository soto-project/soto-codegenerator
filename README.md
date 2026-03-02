# Soto Code Generator

The Code Generator for Soto, generating Swift client code for AWS using the Smithy models provided by AWS.

## Build plugin

The Soto repository is very large and in general most projects only need a few of the many services it supports. To avoid having to download the full project we have built a Swift Package Manager Build Plugin which adds the conversion from Smithy model file to Swift into your build process. 

### Setup

Replace your dependency on Soto in the Package.swift with the following

```swift
.package(url: "https://github.com/soto-project/soto-codegenerator", from: "7.8.4"),
.package(url: "https://github.com/soto-project/soto-core.git", from: "7.13.0"),
```

And the target you want to add the generated Soto code to should be setup as follows
```swift
.target(
    name: "MySotoServices",
    dependencies: [.product(name: "SotoCore", package: "soto-core")],
    plugins: [.plugin(name: "SotoCodeGeneratorPlugin", package: "soto-codegenerator")]
)
```

Add a `soto.config.json` configuration file into the folder for the target you want to add AWS services. This is a json file that details which services you are using. An object is associated with each service. Later on we will discuss how this object can be used to control code generation. 

```json
{
    "services": { 
        "s3": {},
        "iam": {}
    },
}
```

Code generation needs source model files to run. 
- The region endpoint definition file [endpoints.json](https://aws-toolkit-endpoints.s3.amazonaws.com/endpoints.json). This file isn't totally necessary but if your service has custom endpoints you will need access to it.
- The model file for the service you want to use. You can find these in the [aws/api-models-aws](https://github.com/aws/api-models-aws/tree/main/models) repository. 

Both of these should be placed in your target folder. The easiest way to add these to your project is to run the command plugin `download-aws-models`.

```sh
swift package plugin download-aws-models
```

If your target only includes AWS Smithy model files in it, you need to add a dummy empty Swift file to the folder. Otherwise the Swift Package Manager will warn that you have no source files for your target and not build the target. 

Now you can build your project.

```
swift build
```

The build plugin will put the generated Swift code in a sub-folder `.build/plugins/outputs/` and will include it in the list of Swift files for that target.

### Missing Code

If you are dependent on extension code from Soto (eg S3 multipart upload, STS/Cognito credential providers or DynamoDB Codable support), this process may not work for you as the extension code is not generated and will not be available to you.

## Config file

It was mentioned above that the configuration file `soto.config.json` can control the Swift code generation. 

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


