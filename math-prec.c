/*
  Print XVALS lines of the form when N_ARGS == 1

  :: x-val abs-err rel-err b-val # hex-val ticks [!a>] [!a<] [!r>] [!r<] [!t>]

  to the standard output of the host computer.

  * x-val is a float value in the range [X0, X1]

  * abs-err is the absolute error of FUN at x-val.

  * rel-err is the relative error of FUN at x-val.

  * b-val is the relative error in bits. There is no distinction
    of positive or negative relative errors.  b-val shows how
    accurate the computation is in terms of fractional bits.
    For example, the best b-val that can be achieved with a float
    computation is -23 bits because the IEEE float mantissa
    has 23 (fractional) bits.

  * hex-val is the same like x-val but printed in hex-float
    form so that the exact value of x is provided.

  * ticks is the number of consumed CPU cycles.  It may be some cycles off.

  Each line can have ! markers.  A !a< marker means that
  the absolute error is smaller than all previous absolute errors.
  Similarly, a !r> marker means that the relative error is greater
  than all previous relative errors.
*/

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include <avr/pgmspace.h>

#include "avrtest.h"

//////////////////////////////////////////////////////////////////
#if defined(USE_F) && USE_F // Use "float" implementation.

typedef float FF;
#ifndef FUN
#define FUN sinf
#endif
#define host_add avrtest_addf
#define host_sub avrtest_subf
#define host_mul avrtest_mulf
#define host_div avrtest_divf
#define host_log2 avrtest_log2f
#define host_fabs avrtest_fabsf
#define LOG_PFMT_FF LOG_PFMT_FLOAT
#define FBITS 32

#elif defined (USE_L) && USE_L // Use "long double" implementation.
#ifndef HAVE_sinl
#error define HAVE_sinl for properties of long long implementation
#endif
typedef long double FF;
#ifndef FUN
#define FUN sinl
#endif
#define host_add avrtest_addl
#define host_sub avrtest_subl
#define host_mul avrtest_mull
#define host_div avrtest_divl
#define host_log2 avrtest_log2l
#define host_fabs avrtest_fabsl
#define LOG_PFMT_FF LOG_PFMT_LDOUBLE

#if __SIZEOF_LONG_DOUBLE__ == 8
#define FBITS 64
#else
#define FBITS 32
#endif // long double = 8?

#else
#error define USE_F or USE_L
#endif // USE_L / USE_F
//////////////////////////////////////////////////////////////////

#if FBITS == 64
typedef uint64_t uint_t;
#define EXPO_BITS 11
#endif // FBITS == 64

#if FBITS == 32
typedef uint32_t uint_t;
#define EXPO_BITS 8
#endif // FBITS = 32

#define EXPO_BIAS ((1 << (EXPO_BITS-1)) - 1)
#define MANT_BITS (FBITS - 1 - EXPO_BITS) // encoded
#define M_SIGN ((uint_t) 1 << (FBITS - 1))
#define P_INF ((((uint_t) 1 << EXPO_BITS) - 1) << MANT_BITS)

#ifndef XVALS
#define XVALS 101
#endif

#ifndef X0
#define X0 0.0
#endif

#ifndef X1
#define X1 1.0
#endif

uint32_t ticks;

#if N_ARGS == 1
#define _host_val3(fun, x) avrtest_##fun (x)
#define _host_val2(fun, x) _host_val3 (fun, x)
static inline FF host_val (FF x)
{
    return _host_val2 (FUN, x);
}
#elif N_ARGS == 2
#define _host_val3(fun, x, y) avrtest_##fun (x, y)
#define _host_val2(fun, x, y) _host_val3 (fun, x, y)
static inline FF host_val (FF x, FF y)
{
    return _host_val2 (FUN, x, y);
}
#else
#error N_ARGS = ?
#endif // N_ARGS

// FIXME: Only include  math.h  AFTER we expanded FUN because old versions
// of math.h do malicious defines like  #define sinf sin  whih would lead
// to an expansion like avrtest_sin (which does not exist) instead of the
// correct avrtest_sinf for FUN = sinf.
#include <math.h>

#if USE_L && FBITS == 32 && HAVE_sinf == 0
// FIXME: Old version of AVR-LibC does not have long long prototypes.
#define sinl   sinf
#define asinl  asinf
#define sinhl  sinhf
#define asinhl asinhf
#define cosl   cosf
#define acosl  acosf
#define coshl  coshf
#define acoshl acoshf
#define tanl   tanf
#define atanl  atanf
#define tanhl  tanhf
#define atanhl atanhf
#define expl   expf
#define logl   logf
#define sqrtl  sqrtf
#define cbrtl  cbrtf
#define truncl truncf
#define ceill  ceilf
#define floorl floorf
#define roundl roundf
#define log2l  log2f
#define fabsl  fabsf
#define powl   powf
#define atan2l atan2f
#define hypotl hypotf
#define fminl  fminf
#define fmaxl  fmaxf
#define fmodl  fmodf
#endif

static inline FF addf (FF x, FF y) { return x + y; }
static inline FF subf (FF x, FF y) { return x - y; }
static inline FF mulf (FF x, FF y) { return x * y; }
static inline FF divf (FF x, FF y) { return x / y; }

static inline FF addl (FF x, FF y) { return x + y; }
static inline FF subl (FF x, FF y) { return x - y; }
static inline FF mull (FF x, FF y) { return x * y; }
static inline FF divl (FF x, FF y) { return x / y; }

#if N_ARGS == 1
__attribute__((__noinline__,__noclone__))
FF eval_FUN (FF x)
{
    avrtest_reset_cycles();
    __asm volatile ("" : "+r" (x));
    FF w = FUN (x);
    __asm volatile ("" : "+r" (w));

    ticks = avrtest_cycles();
    if (FBITS == 32) ticks -= 5;
    if (FBITS == 64) ticks -= 30;

    return w;
}
#else
__attribute__((__noinline__,__noclone__))
FF eval_FUN (FF x, FF y)
{
    avrtest_reset_cycles();
    __asm volatile ("" : "+r" (x));
    FF w = FUN (x, y);
    __asm volatile ("" : "+r" (w));

    ticks = avrtest_cycles();
    if (FBITS == 32) ticks -= 5;
    if (FBITS == 64) ticks -= 30;

    return w;
}
#endif // N_ARGS


static inline uint_t u_from_f (FF f)
{
    uint_t u;
    __builtin_memcpy (&u, &f, sizeof (u));
    return u;
}

static inline bool is0 (FF f)
{
    uint_t u = u_from_f (f) & ~M_SIGN;
    return u == 0;
}

static inline bool isnum (FF f)
{
    uint_t u = u_from_f (f) & ~M_SIGN;
    return u < P_INF;
}

// Akin %a to print hex float.
void print_float_bin (FF x)
{
    const char *str = NULL;
    const uint_t m_nul = M_SIGN;
    const uint_t p_inf = P_INF;
    const uint_t mant_mask = ~(m_nul | p_inf);

    uint_t v = u_from_f (x);
    bool sign = v & m_nul;

    v &= ~ m_nul;

    if (v > p_inf)
        str = PSTR("nan");
    else
        avrtest_putchar (sign ? '-' : ' ');

    str = str ? str
        : v == 0 ? PSTR("0.0")
        : v == p_inf ? PSTR("inf")
        : NULL;

    if (str)
    {
        LOG_PSTR (str);
        return;
    }

    uint_t mant = v & mant_mask;
    int16_t expo = v >> (MANT_BITS & ~7);
    expo >>= MANT_BITS & 7;

    if (expo)
    {
        // normal
        expo -= EXPO_BIAS;
        LOG_PSTR (PSTR ("0x1."));
    }
    else
    {
        // sub-normal
        expo = 1 - EXPO_BIAS;
        LOG_PSTR (PSTR ("0x0."));
    }

#if FBITS == 32 && MANT_BITS == 23
    mant <<= 1;
    LOG_PFMT_X32 (PSTR("%06x"), mant);
#elif FBITS == 64 && MANT_BITS == 52
    LOG_PFMT_X64 (PSTR("%013llx"), mant);
#else
#error todo
#endif

    LOG_PFMT_S16 (PSTR("p%d"), expo);
}


/* When we compute with N fractional figures, then the best accuracy that
   can be achieved in base B is: 0.5 * B^{-N}.
   The other way round, when we have an accuracy A with an arithmetic
   with N fractional digits, then A corresponds to a digit accuracy of

      acc_bit = log_B (2A) = 1 + log_2 (A) when B = 2

   These values will be negative when there is an accuracy according to
   fractional bits, i.e. "smaller means better".
*/
static FF bitacc (FF err)
{
    if (is0 (err))
        return (FF) -MANT_BITS;

    FF acc = host_add ((FF) 1, host_log2 (host_fabs (err)));
    return acc;
}


static FF val_linear (FF a, FF b, uint16_t n_vals, uint16_t n)
{
    FF len = host_sub (b, a);
    FF dx = host_div (len, n_vals - 1);
    return host_add (a, host_mul ((FF) n, dx));
}


FF abs_mi;
FF abs_ma;
FF rel_mi;
FF rel_ma;
uint32_t cyc_ma = 0;

// Evaluate the function on the AVR target and on the host, and
// determine the absolute and relative error of the calculation
// assuming that the host value is spot on.

int main (void)
{
    const uint16_t x_vals = XVALS;
    const FF x0 = X0;
    const FF x1 = X1;
    abs_mi = __builtin_huge_valf();
    abs_ma = -abs_mi;
    rel_mi = abs_mi;
    rel_ma = abs_ma;
    cyc_ma = 0;

    static FF x, w0, w1, abs_err, rel_err, bit_err;

#if N_ARGS == 2
    const uint16_t y_vals = YVALS;
    const FF y0 = Y0;
    const FF y1 = Y1;
    for (uint16_t iy = 0; iy < y_vals; ++iy)
    {
        static FF y;
        y = val_linear (y0, y1, y_vals, iy);
#endif
    for (uint16_t ix = 0; ix < x_vals; ++ix)
    {
        const char *pfmt_x = FBITS == 32 ? PSTR(" % .8f") : PSTR(" % .15f");
        x = val_linear (x0, x1, x_vals, ix);
#if N_ARGS == 2
        w1 = eval_FUN (x, y);
        if (! isnum (w1)) continue;
        LOG_PSTR (PSTR (":: "));
        LOG_PFMT_FF (pfmt_x, x);
        LOG_PFMT_FF (pfmt_x, y);
        w0 = host_val (x, y);
#else
        w1 = eval_FUN (x);
        if (! isnum (w1)) continue;
        LOG_PSTR (PSTR (":: "));
        LOG_PFMT_FF (pfmt_x, x);
        w0 = host_val (x);
#endif

        abs_err = host_sub (w1, w0);
        rel_err = is0 (w0)
            ? is0 (w1) ? 0 : 1
            : host_div (abs_err, host_fabs (w0));

        LOG_PFMT_FF (PSTR(" % .4e "), abs_err);
        LOG_PFMT_FF (PSTR(" % .4e "), rel_err);

        bit_err = bitacc (rel_err);
        LOG_PFMT_FF (PSTR(" % .2f # "), bit_err);

        print_float_bin (x);
#if N_ARGS == 2
        avrtest_putchar (' ');
        print_float_bin (y);
#endif
        LOG_PFMT_U32 (PSTR(" %u"), ticks);

        if (abs_err < abs_mi)  { abs_mi = abs_err; LOG_PSTR (PSTR (" !a<")); }
        if (abs_err > abs_ma)  { abs_ma = abs_err; LOG_PSTR (PSTR (" !a>")); }

        if (rel_err < rel_mi)  { rel_mi = rel_err; LOG_PSTR (PSTR (" !r<")); }
        if (rel_err > rel_ma)  { rel_ma = rel_err; LOG_PSTR (PSTR (" !r>")); }

        if (ticks > cyc_ma)   { cyc_ma = ticks; LOG_PSTR (PSTR (" !t>")); }

        avrtest_putchar ('\n');
    }
#if N_ARGS == 2
    }
#endif
    return 0;
}
