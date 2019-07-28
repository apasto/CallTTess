# CallTTess
Call [Tesseroids](https://github.com/leouieda/tesseroids) ([Uieda et al., 2016](http://dx.doi.org/10.1190/geo2015-0204.1)) binaries from/to Matlab, to perform forward modelling of gravitational fields.

The set of functions in CallTTess takes care of writing the computation points grid and the tesseroids definition, calling the required binaries, and reading back from input.

Probably not an ideal implementation ⁠—for sure not the most efficient— but it works.
Concurrent processing on parallel workers is possible. It has been implemented through the Parallel Computing Toolbox.

As pointed out in issue [#1](../../issues/1), this is not a proper Readme and the functions still lack adequate documentation.

## Authors

- **Alberto Pastorutti** - [github.com/apasto](https://github.com/apasto)

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.

<sup>MATLAB® is a registered trademark of The MathWorks, Inc.</sup>
