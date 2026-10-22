"""OMP's mnemopi memory bank name for a project folder.

OMP 18.5.1 names a project's bank `<folder name>-<Bun.hash(absolute path)>`,
the hash in base 36. Bun.hash is Zig's std.hash.Wyhash with seed 0. OMP also
cleans the folder name; this tool accepts only names that cleaning cannot
change (lowercase letters, digits and '-').

Usage: python3 omp-bank-name.py ABSOLUTE_PATH ...   prints one bank name per path
       python3 omp-bank-name.py --self-test        checks the names seen on real machines
"""

import os
import re
import sys

M = (1 << 64) - 1
S = (0xA0761D6478BD642F, 0xE7037ED1A0B428DB, 0x8EBC6AF09C88C6E3, 0x589965CC75374CC3)


def mum(a, b):
    x = a * b
    return x & M, (x >> 64) & M


def mix(a, b):
    a, b = mum(a, b)
    return a ^ b


def rd(data, i, n):
    return int.from_bytes(data[i : i + n], "little")


def wyhash(data, seed=0):
    state = [seed ^ mix(seed ^ S[0], S[1])] * 3
    n = len(data)
    if n <= 16:
        if n >= 4:
            end, quarter = n - 4, (n >> 3) << 2
            a = (rd(data, 0, 4) << 32) | rd(data, quarter, 4)
            b = (rd(data, end, 4) << 32) | rd(data, end - quarter, 4)
        elif n > 0:
            a, b = (data[0] << 16) | (data[n >> 1] << 8) | data[n - 1], 0
        else:
            a = b = 0
    else:
        i = 0
        if n >= 48:
            while i + 48 < n:
                for k in range(3):
                    state[k] = mix(
                        rd(data, i + 16 * k, 8) ^ S[k + 1],
                        rd(data, i + 16 * k + 8, 8) ^ state[k],
                    )
                i += 48
            state[0] ^= state[1] ^ state[2]
        rest = data[i:]
        j = 0
        while j + 16 < len(rest):
            state[0] = mix(rd(rest, j, 8) ^ S[1], rd(rest, j + 8, 8) ^ state[0])
            j += 16
        a, b = rd(data, n - 16, 8), rd(data, n - 8, 8)
    a ^= S[1]
    b ^= state[0]
    a, b = mum(a, b)
    return mix(a ^ S[0] ^ n, b ^ S[1])


def base36(x):
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    out = ""
    while x:
        x, r = divmod(x, 36)
        out = digits[r] + out
    return out or "0"


def bank_name(path):
    if not path.startswith("/"):
        raise ValueError(f"not an absolute path: {path}")
    name = os.path.basename(path.rstrip("/"))
    if not re.fullmatch(r"[a-z0-9-]+", name):
        raise ValueError(
            f"folder name {name!r} may be changed by OMP's cleaning; not supported"
        )
    return f"{name}-{base36(wyhash(path.encode()))}"


# OMP itself created the first bank on the Mac. The second is this tool's own
# result for the server's path, kept to catch a regression; OMP has not
# confirmed it, because the server's OMP runs with memory switched off.
KNOWN = {
    "/Users/pwm/work/pml": "pml-1f7ydi2sne7sl",
    "/home/pwm/work/pml": "pml-3q8dfted1lpeg",
}

if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        bad = {p: bank_name(p) for p, want in KNOWN.items() if bank_name(p) != want}
        print("self-test", "failed: " + str(bad) if bad else "passed")
        sys.exit(1 if bad else 0)
    if not sys.argv[1:]:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        print(bank_name(p))
