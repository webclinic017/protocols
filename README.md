# Smart Contract Dev Template

Template for smart contract development using Typescript & Hardhat

[Available Scripts](https://github.com/yuichiroaoki/typescript-hardhat/wiki/Available-Scripts)

[Setup Environment Variables](https://github.com/yuichiroaoki/typescript-hardhat/wiki/Setup-Environment-Variables)

### Steps to deploy a new index contract

1. Create a new Gnosis Safe
2. Deploy a new module (MyModule.sol) - constructor input: safe address
3. Enable module from Gnosis Safe Frontend (Apps -> Zodiac): all owners need to approve to enable the module
4. Deploy price oracle
5. Initialize price oracle (pancakeswap address)
6. Deploy index contract
7. Initialize default (or initialize with tokens that should be in the portfolio)
8. Update rate
9. MyModule contract: transfer ownership to index contract address so the contract can withdraw tokens from the safe
