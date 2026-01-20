// Copyright (c) 2010 Satoshi Nakamoto
// Copyright (c) 2009-present The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <chainparams.h>

#include <arith_uint256.h>           // arith_uint256 + UintToArith256 (kept even if unused later)
#include <chainparamsbase.h>
#include <common/args.h>
#include <consensus/merkle.h>
#include <consensus/params.h>
#include <deploymentinfo.h>
#include <logging.h>
#include <primitives/block.h>
#include <script/interpreter.h>
#include <script/script.h>
#include <tinyformat.h>
#include <uint256.h>
#include <util/chaintype.h>
#include <util/strencodings.h>
#include <util/string.h>

#include <cassert>
#include <cstdint>
#include <cstring>                  // strlen()
#include <limits>
#include <stdexcept>
#include <vector>

using util::SplitString;

/* -------------------------------------------------------------
 * Genesis helpers
 * ------------------------------------------------------------- */
static CBlock CreateGenesisBlock(
    const char* pszTimestamp,
    const CScript& genesisOutputScript,
    uint32_t nTime,
    uint32_t nNonce,
    uint32_t nBits,
    int32_t nVersion,
    const CAmount& genesisReward)
{
    CMutableTransaction txNew;
    txNew.version = 1;
    txNew.vin.resize(1);
    txNew.vout.resize(1);

    txNew.vin[0].scriptSig = CScript()
        << 486604799
        << CScriptNum(4)
        << std::vector<unsigned char>(
               (const unsigned char*)pszTimestamp,
               (const unsigned char*)pszTimestamp + strlen(pszTimestamp));

    txNew.vout[0].nValue = genesisReward;
    txNew.vout[0].scriptPubKey = genesisOutputScript;

    CBlock genesis;
    genesis.nTime = nTime;
    genesis.nBits = nBits;
    genesis.nNonce = nNonce;
    genesis.nVersion = nVersion;
    genesis.vtx.push_back(MakeTransactionRef(std::move(txNew)));
    genesis.hashPrevBlock.SetNull();
    genesis.hashMerkleRoot = BlockMerkleRoot(genesis);
    return genesis;
}

/* -------------------------------------------------------------
 * Aurum main chain params
 * ------------------------------------------------------------- */
class CAurumChainParams : public CChainParams {
public:
    CAurumChainParams()
    {
        /* Network */
        pchMessageStart[0] = 0xfa;
        pchMessageStart[1] = 0xbf;
        pchMessageStart[2] = 0xb5;
        pchMessageStart[3] = 0xda;
        nDefaultPort = 12345;

        /* ---------------------------------------------------------
         * Address / key encodings
         * --------------------------------------------------------- */
        bech32_hrp = "aur"; // aur1...

        // NOTE: These are placeholders; you can pick any values 0-255.
        // If you change them later, old addresses become invalid.
        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1, 23);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1, 5);
        base58Prefixes[SECRET_KEY]     = std::vector<unsigned char>(1, 128);

        /* Consensus */
        consensus.nSubsidyHalvingInterval = 210000; // ✅ ADD: halving interval back
        consensus.nPowTargetSpacing  = 60;          // 60s blocks
        consensus.nPowTargetTimespan = 60 * 60;     // ✅ CHANGE: 1 hour retarget (sane default)

        // ✅ REMOVE: fPowNoRetargeting on MAIN may not exist / may break builds
        // consensus.fPowNoRetargeting  = true;

        // Pow limit (easy)
        consensus.powLimit = uint256::FromHex(
            "0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        ).value();

        /* ---------------------------------------------------------
         * Genesis (LOCKED)  ✅ DO NOT MINE AT STARTUP
         * --------------------------------------------------------- */
        const char* pszTimestamp = "AurumCoin Genesis Block - 2026-01-09";
        const CScript genesisOutputScript = CScript() << OP_TRUE;

        // LOCKED values from your successful run
        const uint32_t nTime    = 1768021699;
        const uint32_t nNonce   = 69110;
        const uint32_t nBits    = 0x1f00ffff;
        const int32_t  nVersion = 1;
        const CAmount  genesisReward = 50 * COIN;

        genesis = CreateGenesisBlock(
            pszTimestamp,
            genesisOutputScript,
            nTime,
            nNonce,
            nBits,
            nVersion,
            genesisReward);

        consensus.hashGenesisBlock = genesis.GetHash();

        // Hard-lock expected hashes so they NEVER change
        const uint256 expectedGenesis = uint256::FromHex(
            "0000d1fba209d1c1c2b6257a4366509c609f0aa904adf1f6d4b9e0a2b88bf5f2"
        ).value();

        const uint256 expectedMerkle = uint256::FromHex(
            "f7587d64228275b3742e7f63fcfd1e4b93bfd1bbf0d8ff00634ea28e4e6b5fc1"
        ).value();

        assert(consensus.hashGenesisBlock == expectedGenesis);
        assert(genesis.hashMerkleRoot == expectedMerkle);

        LogInfo("AurumCoin GENESIS LOCKED");
        LogInfo("hash=%s", consensus.hashGenesisBlock.ToString());
        LogInfo("merkle=%s", genesis.hashMerkleRoot.ToString());
        LogInfo("time=%u", genesis.nTime);
        LogInfo("nonce=%u", genesis.nNonce);
        LogInfo("bits=%08x", genesis.nBits);
    }
};

/* -------------------------------------------------------------
 * Boilerplate (unchanged-ish, but safe)
 * ------------------------------------------------------------- */
void ReadSigNetArgs(const ArgsManager& args, CChainParams::SigNetOptions& options)
{
    if (!args.GetArgs("-signetseednode").empty()) {
        options.seeds.emplace(args.GetArgs("-signetseednode"));
    }
    if (!args.GetArgs("-signetchallenge").empty()) {
        const auto signet_challenge = args.GetArgs("-signetchallenge");
        if (signet_challenge.size() != 1) {
            throw std::runtime_error("-signetchallenge cannot be multiple values.");
        }
        const auto val{TryParseHex<uint8_t>(signet_challenge[0])};
        if (!val) {
            throw std::runtime_error(strprintf("-signetchallenge must be hex, not '%s'.", signet_challenge[0]));
        }
        options.challenge.emplace(*val);
    }
}

void ReadRegTestArgs(const ArgsManager& args, CChainParams::RegTestOptions& options)
{
    if (auto value = args.GetBoolArg("-fastprune")) options.fastprune = *value;
}

static std::unique_ptr<const CChainParams> globalChainParams;

const CChainParams& Params()
{
    assert(globalChainParams);
    return *globalChainParams;
}

std::unique_ptr<const CChainParams> CreateChainParams(
    const ArgsManager& args, const ChainType chain)
{
    switch (chain) {
    case ChainType::MAIN:
        return std::make_unique<CAurumChainParams>();
    case ChainType::TESTNET:
        return CChainParams::TestNet();
    case ChainType::TESTNET4:
        return CChainParams::TestNet4();
    case ChainType::SIGNET: {
        auto opts = CChainParams::SigNetOptions{};
        ReadSigNetArgs(args, opts);
        return CChainParams::SigNet(opts);
    }
    case ChainType::REGTEST: {
        auto opts = CChainParams::RegTestOptions{};
        ReadRegTestArgs(args, opts);
        return CChainParams::RegTest(opts);
    }
    }
    assert(false);
}

void SelectParams(const ChainType chain)
{
    SelectBaseParams(chain);
    globalChainParams = CreateChainParams(gArgs, chain);
}