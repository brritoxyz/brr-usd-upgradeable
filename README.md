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
| 8453                | Base  | BrrUSDRedeemHelper.sol | 0x2D4A73CbA0138861e7eA39945775379bAA5E9cAA | [BaseScan](https://basescan.org/tx/0xb3a559978a682de8ab9a8b0a3263b30bc57ee40e115cb4afd0845602dbdcf69d) |
