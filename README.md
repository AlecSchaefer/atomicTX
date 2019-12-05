# atomicTX
Protocol for atomic cross-chain transactions.

These contracts were written as part of my undergraduate research project
at Brown University. They are a work in progress and have not been tested.

The accompanying research paper and power point can be found here:
https://drive.google.com/open?id=1kErsXVH40-kTkNpr2OjJNrRqCp-lOPg9



Notes:

- abi experimental encoder currently needed because we pass arrays of structs into
functions as parameters.

- Cannot escrow funds in constructor. We need two function calls to set up tx.

- Consider switching to balance proofs.
