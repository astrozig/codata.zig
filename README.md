# codata-zig

`codata-zig` is a Zig library providing physical constants and reference data based on the [CODATA](https://codata.org/about-codata/) recommended values.

# TODO – codata-zig

- [ ] CI/CD
- [ ] Repo, branch rules
- [ ] Add MIT license
- [ ] Release tag

## Overview

This library aims to provide accurate, up-to-date physical constants for scientific and engineering calculations in Zig, following the latest CODATA recommendations.

## Features

- Standard physical constants (e.g., Planck constant, speed of light, elementary charge)
- Easy-to-use Zig API
- Values sourced from [CODATA](https://codata.org/about-codata/) and [NIST](https://physics.nist.gov/cuu/Constants/index.html)

## Installation

Fetch this repository :

```sh
$ zig fetch --save git+https://github.com/astrozig/codata.zig
```

Add it to your `build.zig` :

```diff
const std = @import("std");
+const codata = @import("codata_zig");

pub fn build(b: *std.Build) void {
    // -- snip --

+    const codata_dep = b.dependency("codata_zig", .{
+        .target = target,
+        .optimize = optimize,
+    });

    // Where `exe` represents your executable/library to link to
+    exe.linkLibrary(codata_dep.artifact("codata_zig"));

    // -- snip --
}
```

## Usage

```zig
const codata = @import("codata-zig");

pub fn main() !void {
    const c = codata.speed_of_light_in_vacuum; // Example
    // Use constants in calculations
}
```

## Updating the library constants from new NIST files

```bash
zig run src/gen.zig -- data/CODATA_2022_adjustment.txt
```
