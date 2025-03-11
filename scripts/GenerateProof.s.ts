import { AbiCoder, keccak256, parseEther } from "ethers";
import { generateTree } from "./GenerateTree.s";

export async function generateProof(walletAddress: string, amount: bigint) {
  const tree = await generateTree();
  const leaf = keccak256(
    AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [walletAddress, amount]
    )
  );

  return tree.getHexProof(leaf);
}

generateProof(
  "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
  parseEther("100")
).then((proof) => {
  console.info(`proof: ${proof}`);
});
