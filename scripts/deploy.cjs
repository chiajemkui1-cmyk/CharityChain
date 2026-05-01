require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');

const root = path.resolve(__dirname, '..');
const artifactPath = path.join(root, 'build', 'CharityManager.json');
const rpcUrl = process.env.FUJI_RPC_URL || 'https://api.avax-test.network/ext/bc/C/rpc';
const privateKey = process.env.DEPLOYER_PRIVATE_KEY;

if (!privateKey) {
  console.error('Missing DEPLOYER_PRIVATE_KEY in environment or .env');
  process.exit(1);
}

if (!fs.existsSync(artifactPath)) {
  console.error('Missing build/CharityManager.json. Run npm run compile first.');
  process.exit(1);
}

async function main() {
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const network = await provider.getNetwork();
  const balance = await wallet.getBalance();

  console.log(`Deploying CharityManager to chain ${network.chainId}`);
  console.log(`Deployer: ${wallet.address}`);
  console.log(`Balance: ${ethers.utils.formatEther(balance)} AVAX`);

  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, wallet);
  const contract = await factory.deploy();
  console.log(`Tx: ${contract.deployTransaction.hash}`);

  await contract.deployed();
  console.log(`CharityManager deployed: ${contract.address}`);

  const frontendConfigPath = path.join(root, 'contracts.js');
  const frontendConfig = fs.readFileSync(frontendConfigPath, 'utf8');
  const updatedConfig = frontendConfig.replace(
    /const MANAGER_ADDRESS = '0x[a-fA-F0-9]{40}';/,
    `const MANAGER_ADDRESS = '${contract.address}';`
  );

  if (updatedConfig === frontendConfig) {
    console.warn('Could not update MANAGER_ADDRESS in contracts.js automatically.');
  } else {
    fs.writeFileSync(frontendConfigPath, updatedConfig);
    console.log(`Updated contracts.js MANAGER_ADDRESS to ${contract.address}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
