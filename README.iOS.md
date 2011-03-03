# Introduction

These documents helped a lot:
 
 * https://github.com/esl/erlang-embedded/
 * http://www.erlang.org/doc/installation_guide/INSTALL-CROSS.html
 * http://erlang.2086793.n4.nabble.com/Cross-compiling-with-OpenSSL-td2542347.html
 * http://stuff.thatblogs.com/content/cross-compiling-openssl-how-cross-compile-openssl


# Compile info

The smallest package is obtain by using `./EmbErl.sh -s -S -c -C` (~2.0mb).

Using a bit more than the miniming set of libraries, you can downsize
to the following values:

 *       7.8mb
 * -C    7.1mb
 * -Cc   7.1mb
 * -c    6.9mb
 * -s    2.8mb
 * -sC   2.8mb
 * -sc   2.8mb
 * -scC  2.8mb
 * -sSsC 2.8mb

The compile time on a rather fast Intel quad core 3GHz is ~248s with all
flags set.
 
# Progress

 * Autoconfigure works
 * Configure works
 * Host compilation works
 * Host linking works
 * Target compilation works
 * Target linking works
 * Bundling works
 * erl execution works
 * lib compiler (done! Compiler works! now we can compile on the AppleTV)
 * erlc execution works
 * lib sasl works
 * lib tools works

# Todos

 * Compile using termcap
 * Compile with ssl (with dynamic ssl lib)
 * Add following libraries:
   * mnesia
   * inets
 * Make SSL (crypto, ssl, public\_key) work
   * crypto
   * ssl
   * public\_key
 * Test some system parameters:
   * Run `> erlang:system_info(X).` to see the configuration

# Warnings

I get some warnings when compiling the erl files as well as the c
files, but so far I rather assume they are not relevant enough to
break a running Erlang VM node.

# Hurdles

## Compile and Link Binary location and filenames

### Problem
Just setting the host variable and then let the binaries filename
guess like `$HOST-gcc` does not work for the iOS toolchain, because
the binary filenames are cctually named like `$HOST-gcc-$VERSION`.

### Solution
Set them correctly.


## Undetermined endianness

### Problem
The endianness can not be determined by the autoconfigure script and
is also not set with a default value.

### Solution
As the arm-apple-darwin iOS platform uses little-endian, set the
big-endian autoconfigure flag to `no`:

    erl_xcomp_bigendian=no


## Not available -m32 flag

### Problem
The `-m32` flag is usually set to explicitly express that the system
should be build for a 32-bit architecture. But the iOS GCC compiler
for ARM does not support this flag (yet, as all ARM chips are supposed
to not have 64 bit support).

### Solution
Apply patch to not create the `-m32` flag in configure files. (See
patch file).


## bp_sched2ix function not defined

### Problem
A function was introduced in commit ff9531eb5e6aaa5a4802db0db5e0e850f4233702
(https://github.com/erlang/otp/commit/ff9531eb5e6aaa5a4802db0db5e0e850f4233702). This
function creates problems only so far when linking for an
arm-apple-darwin platform. 

Issues while compiling:
 * erl_init.o
 * erl_bif_trace.o
 * erl_trace.o
 * bif.o
 * erl_process.o
 * erl_nif.o
 * beam_emu.o
 * beam_bif_load.o
 * beam_debug.o

beam/beam_bp.h:147: warning: inline function ‘bp_sched2ix’ declared but never defined

This leads to:

    Undefined symbols:
      "_bp_sched2ix", referenced from:
            _load_nif_2 in erl_nif.o
            ld: symbol(s) not found
            collect2: ld returned 1 exit status
            make[3]: ***
      [/Users/uwe/dev/erlang-embedded/otp_src_R14B01/bin/arm-apple-darwin10/beam]
      Error 1
      make[2]: *** [opt] Error 2
      make[1]: *** [opt] Error 2
      make: *** [emulator] Error 2

The implementation looks like that:

    erts/emulator/beam/beam_bp.h:
    ERTS_INLINE Uint bp_sched2ix(void);

    erts/emulator/beam/beam_bp.c:
    /* bp_hash */
    ERTS_INLINE Uint bp_sched2ix() {
    #ifdef ERTS_SMP
        ErtsSchedulerData *esdp;
        esdp = erts_get_scheduler_data();
        return esdp->no - 1;
    #else
        return 0;
    #endif
    }

### Solution
Remove the `-std=c99` flag from the CFLAG flag.


## Missing utmp.h file in run_erl.c issues

### Problem
    ../unix/run_erl.c:70:20: error: utmp.h: No such file or directory

This file is needed because of the `time_t` struct. This file in fact
exists on the OS X system SDK and the iPhone simulator SDK, but not in
the iPhone SDK. There, the missing struct exists in the `utime.h` file.

### Solution
Patch the run_erl.c file to use `utime.h` instead of `utmp.h`. (Or
copy the `utmp.h` file into the iPhone SDK).


## Missing apps

### Problem
Some apps are not compiled although they are added to the `./keep`
file.

### Solution
The reason for that is that the `otp_build` steps are not executed
using the `-a` flag, thus the `make` variable `OTP_SMALL_BUILD` will
be set, which only includes a small test of library apps.
Change the `otp_build` calls by adding the `-a` flag:

    -./otp_build boot
    +./otp_build boot -a
    # :
    +./otp_build release
    -./otp_build release -a

## Crypto compilation fails

### Problem
    crypto.c:36:33: error: openssl/opensslconf.h: No such file or directory

Crypto can't be compiled, because the openssl library is not present.

After compiling OpenSSL and copying all the header files into the
right path and set the path information, the following error occurs:

    ld: warning: in /usr/lib/bundle1.o, missing required architecture arm in file
    ld: warning: in /usr/lib/libcrypto.dylib, missing required architecture arm in file
    ld: warning: in /usr/lib/libgcc_s.1.dylib, missing required architecture arm in file
    ld: warning: in /usr/lib/libSystem.dylib, missing required architecture arm in file
    ld: symbol dyld_stub_binding_helper not defined (usually in crt1.o/dylib1.o/bundle1.o)
    collect2: ld returned 1 exit status
    make[6]: *** [../priv/lib/arm-apple-darwin10/crypto.so] Error 1
    make[5]: *** [release_spec] Error 2
    make[4]: *** [release] Error 2
    make[3]: *** [release] Error 2
    make[2]: *** [release] Error 2
    make[1]: *** [release] Error 2
    make: *** [release] Error 2

### Solution
???
