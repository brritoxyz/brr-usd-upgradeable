# brrUSD

brrUSD is a yield-bearing USDC derivative built on Compound III's Base USDbC/USDC markets.

brrUSD is easy to use and understand: deposit USDC, receive brrUSD. Your brrUSD can be redeemed at any time for the amount of ETH you originally deposited, plus any interest accrued.

There are no deposit or withdrawal fees, but we may take a reward fee (the amount varies, depending on the specific deployment).

NOTE: Compound III rounds down token balances during transfers, which may result in a ~1-2 wei (an extremely small amount) discrepancy when depositing USDC/cUSDbC or redeeming brrUSD. This is a known issue, and has been communicated to the Compound Labs team, but is ultimately out of our control.

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test --rpc-url https://mainnet.base.org` to compile contracts and run tests.

## Contract Deployments

| Chain ID         | Chain             | Contract | Contract Address                           | Deployment Tx |
| :--------------- | :---------------- | :----------------------------------------- | :----------------------------------------- | :------------ |
