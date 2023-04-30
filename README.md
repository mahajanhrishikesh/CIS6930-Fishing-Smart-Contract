# CIS6930-Fishing-Smart-Contract

To run the solidity code in conjunction with the API follow the steps given below:
1. Get a wallet such as metamask [https://metamask.io/]
2. Connect it to the Sepolia Test network
3. Load the contract into the the remix platform
4. Select the injected provider metamask in the deploy and run transitions side menu
5. Fund the contract with LINK and fund your own wallet with ETH from any faucet of your liking. A good one that we used is available here [https://faucets.chain.link/] or you can use your device to mine some at [https://sepolia-faucet.pk910.de/]
6. Compile and run the code and enter the penalty address as that of your own, you can now run the contract.

Note that the fishing.sol is the main smart contract and the others located in apiTest folder test the three relevant API endpoints without the need for establishing the complex relation and going the whole validation loop for the program. The steps for each of the smart contract in the apiTest folder are same as the ones listed above. 

For API Source Refer: https://github.com/Yash-Shekhadar/blockchain-flask-app
