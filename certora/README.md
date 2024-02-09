# Certora 

This folder provides a fully functional skeleton for integrating with Certora.


## Run From the Command Line

Follow this guide to install the prover and its dependencies:
[Installation Guide](https://docs.certora.com/en/latest/docs/user-guide/getting-started/install.html)

Once installations are set, run from this directory:  
`certoraRun certora/conf/OperatorRegistry.conf`  

## Recommended IDE

We recommended using VSCode with the following extension:
[Certora Verification Language LSP](https://marketplace.visualstudio.com/items?itemName=Certora.evmspec-lsp)
This extension is found in the VSCode extensions/marketplace. It provides syntactic support for the Certora Verification Language (CVL) - the language in which we will be writing specifications.
 
## Files

The folder `specs` contains the specification files.
Folder `confs` contains the configuration files for running the Certora Prover.
Folder harness contains a new Solidity contract that inherits from the original one and add additional getters and checker functions.


## CVL Examples and Docs
See more <a href="https://github.com/Certora/Examples/tree/master/CVLByExample" target="_blank">CVL specification general examples</a>
and <a href="https://docs.certora.com" target="_blank">Documenation</a>.

