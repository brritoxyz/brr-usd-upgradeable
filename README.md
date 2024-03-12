# brrUSD

brrUSD is a yield-bearing USDC derivative built on Compound III's Base USDbC markets.

brrUSD is easy to use and understand: deposit USDbC, receive brrUSD. Your brrUSD can be redeemed at any time for the amount of USDbC you originally deposited, plus any interest accrued.

There are no deposit or withdrawal fees, but we may take a reward fee (the amount varies, depending on the specific deployment).

NOTE: Compound III rounds down token balances during transfers, which may result in a ~1-2 wei (an extremely small amount) discrepancy when depositing USDbC/cUSDbC or redeeming brrUSD. This is a known issue, and has been communicated to the Compound Labs team, but is ultimately out of our control.

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test --rpc-url https://mainnet.base.org` to compile contracts and run tests.

## Contract Deployments

| Chain ID         | Chain             | Contract | Contract Address                           | Deployment Tx |
| :--------------- | :---------------- | :----------------------------------------- | :----------------------------------------- | :------------ |
| 8453                | Base  | BrrUSD.sol | 0xe5d0481E17E89f99512FBCd1483b0eE8692529Ef | [BaseScan](https://basescan.org/tx/0xe3a88da9459bc5555e6cc6825b749462a0c7661786d88191af0241501ee2cded) |
| 8453                | Base  | BrrUSDHelper.sol | 0xD0064B691F06b96De91fB99F9bcC555eF79F4f27 | [BaseScan](https://basescan.org/tx/0xc8a3cdaf29d8e42fbad296240f321463d6c9c4dc26f8cfc837373809610cbc03) |
