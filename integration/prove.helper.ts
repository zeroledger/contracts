import * as snarkjs from "snarkjs";
import path from "path";
import fs from "fs";

// Cache for witness calculator and verification key
let witnessCalculatorCache = new Map();
let vkeyCache = new Map();

async function getWitnessCalculator(directory: string) {
    const out = path.join(__dirname, "../circuits", directory, "build");

    let wc;
    const wasmPath = path.join(out, `${directory}_js/${directory}.wasm`);

    if (!witnessCalculatorCache.has(wasmPath)) {
        const witnessCalculator = (
            await import(
                path.join(out, `${directory}_js/witness_calculator.js`)
            )
        ).default;
        const wasmBuffer = fs.readFileSync(wasmPath);
        wc = await witnessCalculator(wasmBuffer);
        witnessCalculatorCache.set(wasmPath, wc);
    } else {
        wc = witnessCalculatorCache.get(wasmPath);
    }

    return wc;
}

export async function prove(input: any, directory: string) {
    const out = path.join(__dirname, "../circuits", directory, "build");
    const wc = await getWitnessCalculator(directory);
    // Time witness calculation with caching
    const witnessStart = performance.now();
    const wtns = await wc.calculateWTNSBin(input, true);
    const witnessTime = performance.now() - witnessStart;
    console.log(`Witness calculation took ${witnessTime.toFixed(2)}ms`);

    // Time the actual proving
    const proveStart = performance.now();
    const { proof, publicSignals } = await snarkjs.plonk.prove(
        path.join(out, `${directory}.zkey`),
        wtns
    );
    const proveTime = performance.now() - proveStart;
    console.log(`PLONK proving took ${proveTime.toFixed(2)}ms`);

    // Time verification key export with caching
    const vkeyStart = performance.now();
    let vkey;
    const zkeyPath = path.join(out, `${directory}.zkey`);

    if (!vkeyCache.has(zkeyPath)) {
        vkey = await snarkjs.zKey.exportVerificationKey(zkeyPath);
        vkeyCache.set(zkeyPath, vkey);
    } else {
        vkey = vkeyCache.get(zkeyPath);
    }
    const vkeyTime = performance.now() - vkeyStart;
    console.log(`Verification key export took ${vkeyTime.toFixed(2)}ms`);

    // Time verification
    const verifyStart = performance.now();
    const ok = await snarkjs.plonk.verify(vkey, publicSignals, proof);
    const verifyTime = performance.now() - verifyStart;
    console.log(`Verification took ${verifyTime.toFixed(2)}ms`);

    console.log(
        `Total time: ${(
            witnessTime +
            proveTime +
            vkeyTime +
            verifyTime
        ).toFixed(2)}ms`
    );

    if (!ok) throw new Error("Invalid proof");
    return { proof, publicSignals };
}

export async function exportSolidityCallData(proof: any, publicSignals: any) {
    // Get calldata for Solidity verifier
    const calldata = await snarkjs.plonk.exportSolidityCallData(
        proof,
        publicSignals
    );
    // calldata is a string like: '[proofArray][pubSignalsArray]'
    const match = calldata.match(/\[(.*?)\]\[(.*?)\]/);
    if (!match) throw new Error("Invalid calldata format");
    const proofArr: any = match[1]
        .split(",")
        .map((val: string) => val.trim().replace(/"/g, ""));
    const pubSignalsArr: any = match[2]
        .split(",")
        .map((val: string) => val.trim().replace(/"/g, ""));
    return { calldata_proof: proofArr, calldata_pubSignals: pubSignalsArr };
}

// Function to clear caches (useful for testing)
export function clearCaches() {
    witnessCalculatorCache.clear();
    vkeyCache.clear();
}
