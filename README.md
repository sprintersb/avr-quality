This folder contains scripts and files to assess the quality of aspects of the
AVR-LibC implementation.

* [Floating Point Accuracy](#floating-point-accuracy)

## Floating Point Accuracy

The accuracy of the floating-point implementation can be assessed with
the `math-prec.sh` bash script in this folder.

### Required Software

* An avr-gcc installation.
* The [avrtest](https://github.com/sprintersb/atest) AVR core simulator.
avrtest uses the host's native floating-point implementation to provide
syscalls for IEEE-754 single and double emulation on the target.  This
implies the requirement that the host floating-point format matches
the target format: litte endian, 8-bit exponent for 32-bit values,
and 11-bit exponent for the 64-bit values. Otherwise, avrtest will
terminate with an error message when a floating-point syscall is invoked.

* The [Gnuplot](http://www.gnuplot.info) graphing utility.
When Gnuplot is not available, the `math-prec.sh` script can still be used
with option `-P` (don't generate plots).

### Running `math-prec.sh`

A simple way to run the script is to
```
$ cd <sources>/tests/simulate/quality
$ ./math-prec.sh -i
```
which uses the AVR-LibC from an [i]nstalled avr-gcc toolchain.
It reads function specifications from `funcs.txt`, and the
console output will be something like:

```== using avrtest from: $AVRTEST_HOME/avrtest
== quoted lines are: <x> <abs-err> <rel-err> <rel-err-bits> # <x-hex> <cycles>
== writing out-prec/math-prec.html...
== sinf [-0.5, 6.5] == single ========================================
== calc sinf data to: out-prec/e-sinf.data
== sinf min rel error: 2.12777781 -1.1921e-07 -1.4044e-07 -21.76 # 0x1.105b06p1 1858
== sinf max rel error: 6.28333330  2.3283e-10  1.5732e-06 -18.28 # 0x1.922222p2 2039
== sinf min abs error: 1.57222223 -1.1921e-07 -1.1921e-07 -22.00 # 0x1.927d28p0 1880
== sinf max abs error: 4.60555553  1.1921e-07  1.1989e-07 -21.99 # 0x1.26c16cp2 1739
== sinf max  cycles:   6.28333330  2.3283e-10  1.5732e-06 -18.28 # 0x1.922222p2 2039
== sinf mean cycles: 1757.7
== plot sinf abs error to: out-prec/e-sinf-abs.png
== plot sinf rel error to: out-prec/e-sinf-rel.png
== plot sinf rel error in bits to: out-prec/e-sinf-bit.png
...
```

[file](out-prec/math-prec.html)

![text](out-prec/e-logf-rel.png)
