# Google Protobuf - Mac OS X and iOS Support

The script in this gist will help you buid the Google Protobuf library for use
with macOS and/or iOS. The libraries built by this script are
universal and support all iOS device architectures including the simluator.

# Performing the Build

The script will automatically download the tarball from GitHub, so
all you need to do is run the script. Here are some params you can use:

```
$ ./protobuf3-ios.sh --help
Params:
  -i/--interactive          stop after each step and ask for confirmation to proceed
  -m/--master               grab the latest master from GitHub and build it
  -r/--release [RELEASE]    build particular release of protobuf (3.11.4 is default)
  --target [IOS RELEASE]    set iOS deployment target (10.0 is default)
  -d/--disable [ARCH]       exclude ARCH from build (can be 386, x86_64, armv7, armv7s or arm64)

Example (build 3.7.0 interactively):
  ./protobuf3-ios.sh -i -r 3.7.0

Example (build master without any questions asked):
  ./protobuf3-ios.sh --master

Example (build protobuf 3.10.1 to be deployed on iOS 11+):
  ./protobuf3-ios.sh --release 3.10.1 --target 11.0 --disable 386 --disable armv7 --disable armv7s
```


