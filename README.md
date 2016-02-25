# Tiny Path
A tiny, one-file, Monte Carlo path tracer written in a few hundred lines of Ruby. The source accompanied a short talk I gave as an introduction to Ray Tracing (presentation slides available [here]()). The hope is that it provides a simple to understand example.

![image]()

## Features
* Monte Carlo method
* Global illumination
* Diffuse, and specular BRDFs
* Ray-sphere intersection
* Soft shadows
* Anti-aliasing
* Modified Cornell box
* PNG image format output
* Progressive saving

## Usage
```
$ ruby tiny-path.rb --help

Usage: tiny-path.rb [options]
    -w, --width=width                Image width
    -h, --height=height              Image height
    -s, --spp=spp                    Samples per pixel
    -o, --output=filename            Output filename
    -p, --[no-]progressive-save      Save file while rendering
```
To render the scene at 16 samples per pixel, run the following command,
```
$ ruby tiny-path.rb -s 16
```
It will save a file in the same directory titled `output.png`.

## Author
Julian Villella

## License
Tiny Path is available under the MIT license. See the LICENSE file for more info.