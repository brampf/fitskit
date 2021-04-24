<p align="center">
<img src = "Doc/FITSKitBanner@0.5x.png" alt="FitsKit">
</p>

<p align="center">
<a href="LICENSE">
<img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
</a>
<a href="https://swift.org">
<img src="https://img.shields.io/badge/swift-5.2-brightgreen.svg" alt="Swift 5.2">
</a>
</p>

A native Swift library to read and write FITS files

## Description

FITSKit is a pure Swift library to process the image data of [FITS 4.0](https://fits.gsfc.nasa.gov/fits_standard.html) file files, commonly used to store astronomical data. 

The aim is to implement a modern, native [Swift](https://swift.org) library to utilize the full computing power of modern apple hardware. In particuary, I was seeking for a simple solution to read, render & review FITS files on an iPad.

FITSKit is a highly plattform depenedend library. It compiles and runs exclusively on iOS / iPadOS / macCatalyst. It utilizes apples standard libraries Core Image and Accelerate to process, render & manipulate image data stored in FITS files. It is meant as an addition to the general FITS file format library [FitsCore](https://github.com/brampf/fitscore).

| ![FITSCore](Doc/FITSCore128.png) | ![FITSCore](Doc/FITSKit128.png) | ![FITSCore](Doc/FITSTool128.png) |
| :---------------------------------------: | :---------------------------------------: | :---------------------------------------: | 
| [**FITSCore**](https://github.com/brampf/fitscore) | [**FITSKit**](https://github.com/brampf/fitskit) | [**FITSTool**](https://github.com/brampf/fitstool) |
|  Fits file format read & write  | Image rendering & manipulation | Command line tool |
|  macOS, iOS & Linux | iOS / macCatalyst | Linux |

## Features
* Read & Write FITS 4.0 files
    * Image format conversion using Accelerate
    * [x| BITPIX 8 support
    * [x] BITPIX 16 support
    * [] BITPIX 32 support
    * [] BITPIX 64 support
    * [x] BITPIX -32 support
    * [] BITPIX -64 support
* Native code
    * Swift 5.2
    * Compiles for macCatalyst
    * Compiles for iPadOS / iOS

## Getting started

### Package Manager

With the swift package manager, add the library to your dependencies
```swift
dependencies: [
.package(url: "https://github.com/brampf/fitskit.git", from: "0.1.0")
]
```

then simply add the `FITSKit` import to your target

```swift
.target(name: "YourApp", dependencies: ["FITSKit"])
```

## Documentation

#### Rendering Mono
```swift
import FITSKit

// crates core image reference
let cgimage = fitsFile.prime.image { error in
    // print error messages
    print(error)
}
```


## License

MIT license; see [LICENSE](LICENSE.md).
(c) 2020
