# codata.zig

`codata.zig` is a Zig library providing physical constants and reference data based on the [CODATA](https://codata.org/about-codata/) recommended values.

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

## Usage

```zig
const codata = @import("codata-zig");

pub fn main() !void {
    const c = codata.speed_of_light_in_vacuum; // Example
    // Use constants in calculations
}
```

## Updating constants

Generate new constants from src file:

```bash
zig run src/gen.zig -- data/CODATA_2022_adjustment.txt
```
