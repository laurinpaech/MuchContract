# MuchContract
Such DogeBet

Decentralized betting platform

## To compile with solc use:

Compile Test.sol in the .json format, assign the data to a JavaScript variable and send the output into a file:

```
# echo "var testOutput=`solc --optimize --combined-json abi,bin,interface Test.sol`" > test.js
# cat test.js
var testOutput={"contracts":{"Test.sol:Test":{"abi":"[{\"constant\":true,\"inputs\":[],\"name\":\"value\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"inputs\":[],\"payable\":false,\"type\":\"constructor\"}]","bin":"60606040523415600b57fe5b5b607b6000819055505b5b608f806100246000396000f30060606040526000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680633fa4f24514603a575bfe5b3415604157fe5b6047605d565b6040518082815260200191505060405180910390f35b600054815600a165627a7a72305820d0e71d151634ac6ae7626860a17881104022e5cd6d3a088eb8f941d9aa8e3bd20029"}},"version":"0.4.9+commit.364da425.Darwin.appleclang"}
```

In **geth**, load the contents of test.js:

```
$ geth console
...
> loadScript("test.js")
true
> testOutput
{
  contracts: {
    Test.sol:Test: {
      abi: "[{\"constant\":true,\"inputs\":[],\"name\":\"value\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"inputs\":[],\"payable\":false,\"type\":\"constructor\"}]",
      bin: "60606040523415600b57fe5b5b607b6000819055505b5b608f806100246000396000f30060606040526000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680633fa4f24514603a575bfe5b3415604157fe5b6047605d565b6040518082815260200191505060405180910390f35b600054815600a165627a7a72305820d0e71d151634ac6ae7626860a17881104022e5cd6d3a088eb8f941d9aa8e3bd20029"
    }
  },
  version: "0.4.9+commit.364da425.Darwin.appleclang"
}

> testOutput.contracts
{
  abi: "[{\"constant\":true,\"inputs\":[],\"name\":\"value\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"inputs\":[],\"payable\":false,\"type\":\"constructor\"}]",
...
> var testContract = web3.eth.contract(JSON.parse(testOutput.contracts["Test.sol:Test"].abi));
undefined
> personal.unlockAccount(eth.accounts[0], "{top secret password}");
true
> var test = testContract.new({ from: eth.accounts[0], data: "0x" + testOutput.contracts["Test.sol:Test"].bin, gas: 4700000},
  function (e, contract) {
    console.log(e, contract);
    if (typeof contract.address !== 'undefined') {
         console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
    }
  }
);
```
