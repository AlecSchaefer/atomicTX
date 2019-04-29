# atomicTX
Protocol for atomic cross-chain transactions.


Notes:

- abi experimental encoder currently needed because we pass arrays of structs into
functions as parameters.

- Cannot escrow funds in constructor. We need two function calls to set up tx. 

- Use inheritance / factor code??
