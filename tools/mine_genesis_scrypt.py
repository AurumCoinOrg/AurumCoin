#!/usr/bin/env python3
import argparse, struct, hashlib, sys, time

def bits_to_target(bits: int) -> int:
    exp = bits >> 24
    mant = bits & 0x007fffff
    if bits & 0x00800000:
        raise ValueError("negative compact not supported")
    if exp <= 3:
        return mant >> (8 * (3 - exp))
    return mant << (8 * (exp - 3))

def scrypt_hash(header80: bytes) -> bytes:
    # scrypt_1024_1_1_256
    return hashlib.scrypt(header80, salt=header80, n=1024, r=1, p=1, dklen=32)

def to_le_bytes_uint256(hex_be: str) -> bytes:
    hex_be = hex_be.strip().lower()
    if hex_be.startswith("0x"):
        hex_be = hex_be[2:]
    if len(hex_be) != 64:
        raise ValueError("merkle must be 64 hex chars")
    b = bytes.fromhex(hex_be)
    return b[::-1]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", type=int, required=True)
    ap.add_argument("--time", dest="ntime", type=int, required=True)
    ap.add_argument("--bits", type=str, required=True)   # e.g. 0x1e0ffff0
    ap.add_argument("--nonce", type=int, required=True)
    ap.add_argument("--merkle", type=str, required=True) # 64-hex (big-endian display)
    ap.add_argument("--max", type=int, default=0xffffffff)
    ap.add_argument("--progress", type=int, default=200000)
    args = ap.parse_args()

    bits = int(args.bits, 16) if args.bits.lower().startswith("0x") else int(args.bits, 16)
    target = bits_to_target(bits)

    mrkl_le = to_le_bytes_uint256(args.merkle)
    prev_le = b"\x00"*32

    start = time.time()
    n = args.nonce
    checked = 0

    while n <= args.max:
        header = struct.pack("<i", args.version) + prev_le + mrkl_le + struct.pack("<III", args.ntime, bits, n)
        h = scrypt_hash(header)            # 32 bytes little-endian internal
        h_be = h[::-1].hex()              # display big-endian
        h_int = int(h_be, 16)

        if h_int <= target:
            print("FOUND")
            print(f"nonce: {n}")
            print(f"hash: {h_be}")
            return 0

        n += 1
        checked += 1
        if args.progress and (checked % args.progress) == 0:
            dt = time.time() - start
            rate = checked / dt if dt > 0 else 0
            print(f"checked={checked} nonce={n} rate={rate:,.0f}/s", file=sys.stderr)

    print("NOT FOUND (nonce range exhausted)", file=sys.stderr)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
