#! /bin/bash

# Script for testing AVR-LibC fuctions, mainly, by simulating.
# avrtest is needed. The script is tuned to run after 'make'
# without any options, at this place.  Use
#
#     MCUS="..." ./???.sh ...
#
# in order to override the predefined list of mcus.
# Notice that this requires an  exit-<mcu>.o module  for each of the mcus.
# When it is not present, you can generate it with, say
#
#    (cd $AVRTEST_HOME; make exit-<mcu>.o)
#
# Use
#
#     EXTRA_CFLAGS="..." ./???.sh ...
#
# in order to add additional CFLAGS.
# In order to replace the CFLAGS below entirely, use
#
#     CFLAGS="..." ./???.sh ...

set -e

myname="$0"

Errx ()
{
    echo "$myname: $*"
    exit 1
}

Err_echo ()
{
    echo "*** $*"
    Errx "Stop"
}

Verb ()
{
    if [ -z $quiet ]; then
	echo "== $1"
    fi
}

if [ ! -f "$(basename $myname)" ]; then
    Err_echo "please run $(basename $myname) in folder $(dirname $myname)"
fi

: ${AVR_GCC:=avr-gcc}
: ${avrtest:=avrtest}
: ${AVRDIR=../..}

# Plot functions from funcs.txt.  When -f FUNC is specified, plot only FUNC.
FUNC=

# Number of points in the plot, can be set with -n <NUM>.
NUM=1261

# Plot PNG, can be set to SVG with -p svg.
PLOT=png
opt_PLOT=""

# Plot is PX pixels wide and PY pixels high, can be adjusted with -x <PX> -y <PY>.
PX=500
PY=300

# Call "display" (Imagemagick) on the generated PNG file.
do_DISPLAY=0

# AVR MCU as recognized by avr-gcc can be set with -m <MCU>.
MCU=atmega128

# Generate HTML web page, can be switch off with -W.
do_HTML=1

# Output directory, can be adjusted with -o <out_DIR>.
out_DIR="out-prec"

# Whether -C was specified.
do_CLEAN=

OPTS="a:Cdf:g:him:n:o:p:PqvWx:y:"

Usage ()
{
    cat <<EOF
Usage: $1 [-a AVRDIR] [-g AVR_GCC] [-hCdiPqvW] [-f FUNC,x0,x1[,y0,y1]] [-n NUM] [-p FMT] [-x PX] [-y PY] [-o DIR]
Options:
  -a AVRDIR   Specify AVR-LibC $builddir (default: $AVRDIR) for an AVR-LibC just being
              built.
  -C          Make clean: Remove all generated files in folder as given by -o DIR
  -d          Run "display" on the generated PNG file.  This is only run
              when -f FUNC is used, i.e. there is just one output file.
  -i          Test an installed AVR-LibC
  -g AVRGCC   Specify avr-gcc program (default: $AVR_GCC)
  -f FUNC,x0,x1[,y0,y1[,Xcoor]]
              Plot accuracy of a function FUNC over [x0, x1] resp. [x0, x1] x [y0, y1].
              If not set, then use the list of functions from funcs.txt.
              Supported function names are float and long double function as supported
              by C/C++ like sinf, sinl, atan2f, etc. and also functions for basic
              arithmetic addf, mulf, divl, etc.  The number of arguments is specified
              implicitly by the provided interval bounds.
              For binary functions, Xcoor specifies how to compute the x-coordinate
              in plots for functions like atan2f or powl.  Possible values for Xcoor
              are: x (default), y, abs, arg where the latter two are the absolut
              value resp. the argument of (x,y).
  -h          Print this help
  -m MCU      Specify the AVR device (default: $MCU)
  -n NUM      Plot NUM values in [x0, x1] resp. [x0, x1] x [y0, y1] (default: $NUM)
  -o DIR      Set the output directory for generated data and images (default: $out_DIR)
  -p FMT      Generate plot files with FMT in: png, svg (default: $PLOT)
  -P          Do NOT denerate plot files (default: generate $PLOT files)
  -q          Quiet mode. Do not babble to the console as the script is running
  -v          Verbose mode; echo shell commands being executed
  -W          Do not write a Web page (HTML) to $HTML_file
  -x PX       X size of generated graphics (default: $PX)
  -y PY       Y size of generated graphics (default: $PY)
If FILE is not specified, the full test list is used.
EOF
}

# First option pass for -h only so that we get the defaults right when
# options like -a are specified.
while getopts $OPTS opt ; do
    case $opt in
	h)	Usage `basename $myname` ; exit 0 ;;
    esac
done

# Second option pass: When -h was not specified, do the work.
unset OPTIND
while getopts $OPTS opt ; do
    case $opt in
	a)	AVRDIR="$OPTARG" ;;
	d)	do_DISPLAY=1 ;;
	i)	AVRDIR= ;;
	g)	AVR_GCC="$OPTARG" ;;
	f)      FUNC="$OPTARG" ;;
	m)	MCU="$OPTARG" ;;
	n)	NUM="$OPTARG" ;;
	o)	out_DIR="$OPTARG" ;;
	p)	PLOT="$OPTARG"; opt_PLOT="-p $OPTARG" ;;
	P)	PLOT= ; opt_PLOT="-P" ;;
	q)	quiet=1 ;;
	v)	set -x ;;
	W)	do_HTML=0 ;;
	x)	PX="$OPTARG" ;;
	y)	PY="$OPTARG" ;;
	C)      do_CLEAN=1 ;;
	*)	Errx "Invalid option(s). Try '-h' for more info."
    esac
done

if [ "$do_CLEAN" = "1" ]; then
    for ex in html data png svg elf; do
	rm -f "$out_DIR"/*.$ex
    done
    rm --dir "$out_DIR"
    exit 0
fi

if [ -z $AVRTEST_HOME ] ; then
    # AVRTEST_HOME is not set, try which
    ahome=$(which $avrtest)
    if [ $? -eq 0 ] ; then
	AVRTEST_HOME=$(dirname $ahome)
    fi
fi
if [ -z $AVRTEST_HOME ] ; then
    Err_echo "avrtest simulator not found, set AVRTEST_HOME or add avrtest to PATH"
fi

Verb "using $avrtest from: ${AVRTEST_HOME}"

mkdir -p "$out_DIR" || Err_echo "cannot mkdir -p $out_DIR"

ELF="$out_DIR/a.elf"
HTML_file="$out_DIR/math-prec.html"

CPPFLAGS="-I${AVRTEST_HOME}"
CFLAGS=${CFLAGS-"-W -Wall -pipe -Os -std=gnu99 ${CFLAGS_EXTRA}"}


# $1 = MCU as understood by ave-gcc.
# o_gcc: Extra options for avr-gcc
# o_sim: Extra options for avrtext
set_extra_options ()
{
    # As avrtest is just simulating cores, not exact hardware, we can
    # add more RAM at will.

    o_gcc="-mmcu=$1" # Extra options for gcc
    o_sim= # Extra options for avrtest.  Default mmcu=avr51

    case $1 in
	atmega128 | atmega103)
	    ;;
	atmega2560)
	    o_sim="-mmcu=avr6"
	    ;;
	attiny3216)
	    o_sim="-mmcu=avrxmega3"
	    ;;
	atxmega128a3)
	    o_sim="-mmcu=avrxmega6"
	    ;;
	atxmega128a1)
	    o_sim="-mmcu=avrxmega7"
	    ;;
	avr128da32)
	    o_sim="-mmcu=avrxmega4"
	    ;;
	at90s8515)
	    o_sim="-mmcu=avr2"
	    ;;
	*)
	    echo "Define extra options for $1"
	    exit 1
	;;
    esac
    o_gcc="$o_gcc $AVRTEST/exit-$1.o"
}


# $1 = ELF file
# $2 = mcu as understood by avr-gcc
# Extra options for avrtest are passed in o_sim.
Simulate_avrtest ()
{
    # avrtest has 3 flavours: avrtest, avrtest-xmega and avrtest-tiny.
    local suff=
    case "$o_sim" in
	*avrxmega* ) suff="-xmega" ;;
	*avrtiny*  ) suff="-tiny"  ;;
    esac

    msg=$(${AVRTEST_HOME}/${avrtest}${suff}  \
	  -q -no-stdin $1 $o_sim -m 60000000000 2>&1)
    RETVAL=$?
    #echo "MSG = $msg"
    [ $RETVAL -eq 0 ]
}


# Usage: Compile SRCFILE MCU EXTRA-OPTS [CONT-ON-ERROR]
Compile ()
{
    local crt=
    local libs=
    local flags=

    if [ -z "$AVRDIR" ] ; then
	  libs=""
    else
      local multilibdir=`$AVR_GCC -mmcu=$2 -print-multi-directory`
      # Use the same replacements like in mlib-gen.py::to_ident() and
      # configure.ac's CHECK_AVR_DEVICE.  This flattens out the multilib path.
      # For example, "avr25/tiny-stack" becomes "avr25_tiny_stack",
      # and "." becomes "avr2".
      multilibdir=$(echo "$multilibdir"     \
                    | sed -e 's:^\.$:avr2:' \
                    | sed -e 's:/:_:g'      \
                    | sed -e 's:-:_:g')
      crt=crt$2.o
      flags="-isystem $AVRDIR/include -nostdlib"
      crt=`find $AVRDIR/avr/devices -name $crt -print | head -1`
      libs="$AVRDIR/avr/lib/$multilibdir/libc.a	\
            $AVRDIR/avr/lib/$multilibdir/libm.a \
            $AVRDIR/avr/devices/$2/lib$2.a -lgcc"
    fi

    if [ -z "$4" ]; then
	$AVR_GCC $o_func $1 -mmcu=$2 $CPPFLAGS $CFLAGS $flags $crt $o_gcc $libs $3
    else
	$AVR_GCC $o_func $1 -mmcu=$2 $CPPFLAGS $CFLAGS $flags $crt $o_gcc $libs $3 \
	    > /dev/null 2>&1 || return 1
	return 0
    fi
}


# Compile and simulate a C file to produce DATA_FILE as avrtest output.
# Usage: Make_data DATA_FILE
Make_data ()
{
    Compile math-prec.c $MCU "-o $ELF"

    # Get FBITS define from the target program
    fbits=$(Compile math-prec.c $MCU "-E -dM" 2>&1 \
		| grep '#define FBITS '\
		| awk '{ print $3 }' )

    if [ "$fbits" = 32 ]; then
	mant_bits=23
	IEEE="single"
    elif [ "$fbits" = 64 ]; then
	mant_bits=52
	IEEE="double"
    else
	Err_echo "FBITS=$fbits"
    fi

    Simulate_avrtest "$ELF" \
	|| Err_echo "avrtest failed $(echo "$msg" | grep -v '^::')"

    grep "^::" <<< "$msg" | sed -e 's/^:://' > $1
}

# Set_gplot_progs FUN DATA
Set_gplot_progs ()
{
    col_x=1
    col_abs=$((1 + $n_args))     # 2 or 3
    col_rel=$((2 + $n_args))     # 3 or 4
    col_bit=$((3 + $n_args))     # 4 or 5
    col_hash=$((4 + $n_args))    # 5 or 6 ##########
    col_hex=$((5 + $n_args))     # 6 or 7
    col_cyc=$((5 + 2*$n_args))   # 7 or 9

    col_y=2
    col_hey=8

    # Use the hex-float values for Gnuplot because they will also work for
    # very small (by absolute value) values.
    case "$Xcoor" in
	x) xspec=$col_hex ;;
	y) xspec=$col_hey ;;
	abs) xspec='(sqrt($1*$1 + $2*$2))' ;;
	arg) xspec='(atan2($2, $1))' ;;
	*) Err_echo "invalid Xcoor in: $fspec"
    esac
    if [ "$n_args" = 1 ]; then
	xspec=$col_hex
    fi

    local atx='"x = " $1 " = " $'$col_hex
    local aty='"y = " $2 " = " $'$col_hey
    local atxy='" at "'"$atx"
    if [ $n_args = 2 ]; then
       atxy='" at " '"$atx"' ", " '"$aty"
    fi
    awk_rel='{ print $'$col_rel' " (" $'$col_bit' " bits = " ($'$col_bit"+$mant_bits"') " LSBs)"'"$atxy"' }'
    awk_abs='{ print $'$col_abs"$atxy"' }'
    awk_cyc='{ print $'$col_cyc"$atxy"' }'

    awk_mean_cyc='BEGIN{ s = 0 } { s += $'$col_cyc' } END{ printf ("%.1f", s / NR) }'

    local style_err='impulses linetype rgb "#d01010"'
    local style_bit='points linetype rgb "#d01010"'
    local style_cyc='points linetype rgb "#d01010"'

    title_abs="$1 absolute error"
    title_rel="$1 relative error"
    title_bit="$1 relative error in LSBs"
    title_cyc="$1 CPU cycles"

    file_abs="$(dirname $data)/e-$1-abs.$PLOT"
    file_rel="$(dirname $data)/e-$1-rel.$PLOT"
    file_bit="$(dirname $data)/e-$1-bit.$PLOT"
    file_cyc="$(dirname $data)/e-$1-cyc.$PLOT"

    prog_abs=$(cat <<EOF
	set terminal $PLOT size $PX,$PY;
	set key title "$title_abs";
	set output "$file_abs";
	plot "$2" using $xspec:$col_abs title "" with $style_err;
EOF
)
    prog_rel=$(cat <<EOF
	set terminal $PLOT size $PX,$PY;
	set output "$file_rel";
	set key title "$title_rel";
	plot "$2" using $xspec:$col_rel title "" with $style_err,
		+2**(-$mant_bits-1) title "" with lines lt rgb "#00c000",
		-2**(-$mant_bits-1) title "" with lines lt rgb "#00c000";
EOF
)
    prog_bit=$(cat <<EOF
	set terminal $PLOT size $PX,$PY;
	set key title "$title_bit";
	set output "$file_bit";
	plot "$2" using $xspec:($mant_bits+\$$col_bit) title "" with $style_bit,
		1 title "" with lines lt rgb "#00c000";
EOF
)
    prog_cyc=$(cat <<EOF
	set terminal $PLOT size $PX,$PY;
	set key title "$title_cyc";
	set output "$file_cyc";
	plot "$2" using $xspec:$col_cyc title "" with $style_cyc;
EOF
)

}

trim ()
{
    echo "$1" | sed -e 's:^[ \t]*::' -e 's:[ \t]*$::'
}

# Usage Split_func FUNSPEC
# Sets: fx, n_args, x0, x1, Nx, [y0, y1, Ny]
Split_func ()
{
    fspec="$1"
    fx=$(trim $(cut -d "," -f 1 <<< "$1"))
    x0=$(trim $(cut -d "," -f 2 <<< "$1"))
    x1=$(trim $(cut -d "," -f 3 <<< "$1"))

    local n_elem=$(awk -F, '{ print NF }' <<< "$1")
    Xcoor="x"

    case  "$n_elem" in
	3) n_args=1
	   Nx="$NUM"
	   ;;
	5|6) n_args=2
	   y0=$(trim $(cut -d "," -f 4 <<< "$1"))
	   y1=$(trim $(cut -d "," -f 5 <<< "$1"))
	   # Distribute the NUM values to [x0, x1] and [y0, y1] in such a way that
	   # NUM = Nx * Ny approximately, and the density of Nx in [x0, x1] is the
	   # same like the density of Ny in [y0, y1].
	   Nx=$(bc <<< "scale=0; 2 + sqrt($NUM * ($x1-($x0)) / ($y1-($y0)))")
	   Ny=$(bc <<< "scale=0; 2 + sqrt($NUM * ($y1-($y0)) / ($x1-($x0)))")
	   if [ "$n_elem" = 6 ]; then
	       Xcoor=$(trim $(cut -d "," -f 6 <<< "$1"))
	   fi
	   ;;
	*) Err_echo "$FUNC: spec f,x0,x1[,y0,y1[,Xcoor]] must have 3, 5 or 6 values, has $n_elem: $FUNC" ;;
    esac
}

# Usage: Plot_accuracy  FUNC
# More options are shipped in variables: o_func, o_gcc, o_sum, CFLAGS, ...
Plot_accuracy ()
{
    local fx="?"
    local n_args="?"
    local x0="?"
    local x1="?"
    local y0="?"
    local y1="?"

    Split_func "$1"

    if [ -z $did_quote ]; then
	did_quote="true"
	local lfmt
	if [ $n_args = 1 ]; then
	    lfmt="<x> <abs-err> <rel-err> <rel-err-bits> # <x-hex> <cycles>"
	else
	    lfmt="<x> <y> <abs-err> <rel-err> <rel-err-bits> # <x-hex> <y-hex> <cycles>"
	fi
	Verb "quoted lines are: $lfmt"
    fi

    ##################################################################
    ## Step 1: Compile and simulate a small C file to produce $data.

    # "sin" for "sinl" or "sinf"
    func_name=$(sed -e 's:[lf]$::' <<< $fx)

    o_func="-DFUN=$fx -DN_ARGS=$n_args -DHAVE_sinl=$have_sinl"
    o_func="${o_func} -DX0=$x0 -DX1=$x1 -DXVALS=$Nx"

    y_range=""
    if [ "$n_args" = 2 ]; then
	y_range=" x [$y0, $y1]"
	o_func="${o_func} -DY0=$y0 -DY1=$y1 -DYVALS=$Ny"
    fi

    if [[ $fx =~ f$ ]]; then
	o_func="${o_func} -DUSE_F"
    elif [[ $fx =~ l$ ]]; then
	o_func="${o_func} -DUSE_L"
    else
	Err_echo "unknown function $fx must end in 'f' or 'l'"
    fi

    local data="$out_DIR/e-$fx.data"
    Verb "calc $fx data to: $data"

    # $data column      | unary | binary
    # ------------------+-------+--------
    # x-values          |  1    |   1
    # y-values          |       |   2
    # abs error         |  2    |   3
    # rel error         |  3    |   4
    # rel error in bits |  4    |   5
    # #                 |  5    |   6
    # x-value in hex    |  6    |   7
    # y-value in hex    |       |   8
    # cycles            |  7    |   9
    Make_data "$data"

    Verb "$fx [$x0, $x1]${y_range} == $IEEE ========================"

    local min_rline=$(grep '!r<' $data | tail -1 | sed -e 's:!.*::')
    local max_rline=$(grep '!r>' $data | tail -1 | sed -e 's:!.*::')
    local min_aline=$(grep '!a<' $data | tail -1 | sed -e 's:!.*::')
    local max_aline=$(grep '!a>' $data | tail -1 | sed -e 's:!.*::')
    local max_tline=$(grep '!t>' $data | tail -1 | sed -e 's:!.*::')

    Set_gplot_progs $fx "$data"

    local mean_cyc=$(awk -e "$awk_mean_cyc" $data)
    Verb "$fx min rel error: $min_rline"
    Verb "$fx max rel error: $max_rline"
    Verb "$fx min abs error: $min_aline"
    Verb "$fx max abs error: $max_aline"
    Verb "$fx max  cycles: $max_tline"
    Verb "$fx mean cycles: $mean_cyc"

    if [ "$do_HTML" = "1" ]; then
	cat <<EOF >> $HTML_file
<hr/>
<h2>$fx [$x0, $x1]$y_range IEEE $IEEE <a href="$(basename $data)">data</a></h2>
<table>
EOF
    fi

    ##################################################################
    ## Step 2: Compile and simulate a small C file to produce $data.
    if [ -n "$PLOT" ]; then

	display_plot="$file_rel"

	Verb "plot $fx abs error to: $file_abs"
	gnuplot -e "$prog_abs"

	Verb "plot $fx rel error to: $file_rel"
	gnuplot -e "$prog_rel"

	Verb "plot $fx rel error in LSBs to: $file_bit"
	gnuplot -e "$prog_bit"

	Verb "plot $fx cycles: $file_cyc"
	gnuplot -e "$prog_cyc"

	if [ "$do_HTML" = "1" ]; then
	    cat <<EOF >> $HTML_file
<tr><td><img src="$(basename $file_abs)" alt="$title_abs" /></td></tr>
<tr><td><img src="$(basename $file_rel)" alt="$title_rel" /></td></tr>
<tr><td><img src="$(basename $file_bit)" alt="$title_bit" /></td></tr>
<!-- tr><td><img src="$(basename $file_cyc)" alt="$title_cyc" /></td></tr -->
EOF
	fi
    fi # PLOT ?

    if [ "$do_HTML" = "1" ]; then
	local min_rel=$(echo "$min_rline" | awk "$awk_rel")
	local max_rel=$(echo "$max_rline" | awk "$awk_rel")
	local min_abs=$(echo "$min_aline" | awk "$awk_abs")
	local max_abs=$(echo "$max_aline" | awk "$awk_abs")
	local max_cyc=$(echo "$max_tline" | awk "$awk_cyc")
	cat <<EOF >> $HTML_file
<tr><td><ul>
  <li>$fx min rel error: $min_rel</li>
  <li>$fx max rel error: $max_rel</li>
  <li>$fx min abs error: $min_abs</li>
  <li>$fx max abs error: $max_abs</li>
  <li>$fx max cycles: $max_cyc</li>
  <li>$fx meam cycles: $mean_cyc</li>
</ul></td></tr>
</table>
EOF
    fi
}
##################################################################

HTML_head=$(cat <<EOF
<!doctype html>
<html itemtype="http://schema.org/WebPage">
<head><title>math prec</title></head>
<body>
EOF
)

HTML_tail=$(cat <<EOF
</body>
</html>
EOF
)

set_extra_options $MCU

gcc_VER=$($AVR_GCC --version | head -1)
libc_VER=$(echo '#include <avr/version.h>' \
	       | Compile "-xc - -xnone" $MCU "-E -dM" 2>&1 \
	       | grep '#define __AVR_LIBC_VERSION_STRING__ ' \
	       | awk -F'"' '{ print $2 }')

Verb "using avr-gcc: $gcc_VER"
Verb "using AVR-LibC: $libc_VER"

# Do we have the sinl prototype? -> have_sinl=1
have_sinl=0
set +e
msg=$(echo '#include <math.h>' \
	     | Compile "-xc - -xnone" $MCU "-E" 2>&1 \
	     | grep '\bsinl\b')
set -e
if [ -n "$msg" ]; then
    have_sinl=1
fi
Verb "have sinl prototype: have_sinl=$have_sinl"

# # Do we have the sinl function? -> have_sinl=2
# if [ $have_sinl = 1 ]; then
#     prog=$(cat <<EOF
# #include <math.h>
# long double f (long double x) { return sinl (x); }
# int main (void) { return 0; }
# EOF
# 	)
#     set +e
#     printf "$prog" | Compile "-xc - -xnone" $MCU "-o $ELF" 1
#     have_sinl=$((2 - $?))
#     set -e
# fi
# Verb "have sinl prototype and function: have_sinl=$have_sinl"


if [ "$do_HTML" = "1" ]; then
    Verb "writing ${HTML_file}..."
    cat <<EOF > $HTML_file
$HTML_head
<big>
  $gcc_VER
  <br/>AVR-LibC $libc_VER
</big>
  <br/><big>Plot $MCU: </big> <tt>$myname $*</tt>
EOF
fi

if [ ! -z "$FUNC" ]; then
    Plot_accuracy $FUNC

    if [ "$PLOT" = "png" ] && [ "$do_DISPLAY" = "1" ]; then
	Verb "displaying $display_plot..."
	display "$display_plot"
    fi
else
    while read -r line; do
	# Get rid of # comments.
	line=$(sed -e 's:#.*::' <<< "$line")
	if [[ $line =~ ^[[:space:]]*$ ]]; then
	    # An empty line or a line with just a # comment.
	    continue
	fi

	Plot_accuracy "$line"

    done < funcs.txt
fi

if [ "$do_HTML" = "1" ]; then
    echo "$HTML_tail" >> $HTML_file
    Verb "done writing ${HTML_file}"
fi

Verb "done $myname"
