const fs = require('fs');
const path = require('path');
const solc = require('solc');

const root = path.resolve(__dirname, '..');
const contractsDir = path.join(root, 'contracts');
const buildDir = path.join(root, 'build');

const sources = {};
for (const file of fs.readdirSync(contractsDir)) {
  if (file.endsWith('.sol')) {
    const fullPath = path.join(contractsDir, file);
    sources[file] = { content: fs.readFileSync(fullPath, 'utf8') };
  }
}

const input = {
  language: 'Solidity',
  sources,
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: {
      '*': {
        '*': ['abi', 'evm.bytecode.object'],
      },
    },
  },
};

const output = JSON.parse(solc.compile(JSON.stringify(input)));
const errors = output.errors || [];
for (const error of errors) {
  const line = error.formattedMessage || error.message;
  if (error.severity === 'error') {
    console.error(line);
  } else {
    console.warn(line);
  }
}

if (errors.some((error) => error.severity === 'error')) {
  process.exit(1);
}

fs.mkdirSync(buildDir, { recursive: true });

for (const [sourceName, contracts] of Object.entries(output.contracts)) {
  for (const [contractName, artifact] of Object.entries(contracts)) {
    fs.writeFileSync(
      path.join(buildDir, `${contractName}.json`),
      JSON.stringify({
        contractName,
        sourceName,
        abi: artifact.abi,
        bytecode: artifact.evm.bytecode.object,
      }, null, 2)
    );
    console.log(`Wrote build/${contractName}.json`);
  }
}
