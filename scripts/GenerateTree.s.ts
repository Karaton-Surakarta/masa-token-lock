import { MerkleTree } from "merkletreejs";
import { ethers, keccak256 } from "ethers";

export async function generateTree(): Promise<MerkleTree> {
  const recipients = [
    ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 100000000000000000000n], // 100 tokens with 18 decimals
    ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 50000000000000000000n], // 50 tokens
    ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", 25000000000000000000n], // 25 tokens
  ];

  // Generate the leaves of the merkle tree
  const leaves = recipients.map((recipient) => {
    const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [recipient[0], recipient[1]]
    );
    return keccak256(encodedData);
  });

  // Create the merkle tree
  const merkleTree = new MerkleTree(leaves, keccak256, {
    sortPairs: true,
  });

  // Get the root of the merkle tree
  const root = merkleTree.getHexRoot();
  console.info(`root: ${root}`);
  console.info(`merkle tree:\n ${merkleTree.toString()}`);

  return merkleTree;
}

generateTree();
