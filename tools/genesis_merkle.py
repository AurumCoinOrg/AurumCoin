#!/usr/bin/env python3
import hashlib, struct, argparse, binascii

def sha256(b: bytes) -> bytes:
    return hashlib.sha256(b).digest()

def dbl_sha256(b: bytes) -> bytes:
    return sha256(sha256(b))

def ser_compact(n: int) -> bytes:
    if n < 253:
        return bytes([n])
    if n <= 0xffff:
        return b'\xfd' + struct.pack('<H', n)
    if n <= 0xffffffff:
        return b'\xfe' + struct.pack('<I', n)
    return b'\xff' + struct.pack('<Q', n)

def ser_string(b: bytes) -> bytes:
    return ser_compact(len(b)) + b

def ser_uint32(n: int) -> bytes:
    return struct.pack('<I', n)

def ser_int32(n: int) -> bytes:
    return struct.pack('<i', n)

def ser_uint64(n: int) -> bytes:
    return struct.pack('<Q', n)

def ser_outpoint(txid32_le: bytes, vout: int) -> bytes:
    return txid32_le + struct.pack('<I', vout)

def ser_script(script: bytes) -> bytes:
    return ser_string(script)

def ser_txin(prev_txid32_le: bytes, prev_vout: int, script_sig: bytes, sequence: int) -> bytes:
    return ser_outpoint(prev_txid32_le, prev_vout) + ser_script(script_sig) + struct.pack('<I', sequence)

def ser_txout(value_sats: int, script_pubkey: bytes) -> bytes:
    return struct.pack('<q', value_sats) + ser_script(script_pubkey)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timestamp", required=True, help="pszTimestamp string")
    ap.add_argument("--pubkeyhex", required=True, help="genesisOutputScript pubkey hex (the big 04... you have)")
    ap.add_argument("--reward", type=int, required=True, help="genesis reward in coins (e.g. 56)")
    ap.add_argument("--coin", type=int, default=100000000, help="COIN (default 1e8)")
    args = ap.parse_args()

    psz = args.timestamp.encode("utf-8")
    pubkey = bytes.fromhex(args.pubkeyhex)

    # Build scriptSig: CScript() << 486604799 << CScriptNum(4) << vector(pszTimestamp)
    # 486604799 == 0x1d00ffff (Aurum's original), 4 is the "difficulty" string length marker in old code.
    # The modern CreateGenesisBlock in Aurum Core still uses these exact pushes.
    #
    # scriptSig bytes are:
    #   push(486604799 as little-endian) + push(4) + push(timestamp bytes)
    def push_data(b: bytes) -> bytes:
        l = len(b)
        if l < 0x4c:
            return bytes([l]) + b
        raise ValueError("unexpected long push")

    scriptSig = b""
    scriptSig += push_data(struct.pack("<I", 486604799))
    scriptSig += push_data(b"\x04")
    scriptSig += push_data(psz)

    # Coinbase tx:
    version = 1
    locktime = 0
    vin = [ser_txin(b"\x00"*32, 0xffffffff, scriptSig, 0xffffffff)]
    vout = [ser_txout(args.reward * args.coin, b"\x41" + pubkey + b"\xac")]  # OP_DATA65 <pubkey> OP_CHECKSIG
    tx = ser_int32(version) + ser_compact(len(vin)) + b"".join(vin) + ser_compact(len(vout)) + b"".join(vout) + ser_uint32(locktime)

    txid = dbl_sha256(tx)  # little-endian internal
    merkle = txid  # single tx
    print(merkle[::-1].hex())  # display big-endian
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
