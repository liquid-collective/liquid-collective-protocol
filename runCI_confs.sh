# certoraRun certora/confs_for_CI/AllowlistV1.conf          # https://prover.certora.com/output/3106/5b6efb5fe0244ab8a4745998fa02cc9b/?anonymousKey=b96131461c684c9af23b942d657d80b67e7cb186
# certoraRun certora/confs_for_CI/RiverV1.conf              # https://prover.certora.com/output/3106/fba425ad892c4c13b0d6f292519a6b06/?anonymousKey=9bce940acde19f01c54eab61d01d1139c929535b
# certoraRun certora/confs_for_CI/SharesManagerV1.conf      # https://prover.certora.com/output/3106/987084d2a5894248923662c86a20534d/?anonymousKey=59b86e7c093ce7a59eb4ac91cc69b68f09c06ee3
# certoraRun certora/confs_for_CI/RedeemManagerV1.conf      # https://prover.certora.com/output/3106/e783ff3d051246f2a15c6d524545fdaf/?anonymousKey=659dda3e602f596c4fd984deaac12ea30cf5ab73






# certoraRun certora/confs_for_CI/OperatorRegistryV1_1.conf
# https://prover.certora.com/output/3106/c7f62106a0d342898573861859ef3b75/?anonymousKey=b3843d9836ca1fe5f0a1b79ccda60b4fb4223c1b
# Fine with 4 loops: newNOHasZeroKeys removeValidatorsRevertsIfKeysDuplicit removeValidatorsRevertsIfKeysNotSorted
# the rest doesn't work

# running without 3 above and with 5 loops
# hardstop: https://prover.certora.com/output/3106/6e045400e785437e921e89391bb02c3a/?anonymousKey=5e1d3e14038b1f327067b27f002a9ad524bb221d
# whoCanChangeOperatorsCount_IL4 was verified

# running separately with 5 loops
# certoraRun certora/confs_for_CI/OperatorRegistryV1_1.conf --rule validatorStateTransition_1in_M15 --msg "validatorStateTransition_1in_M15"    # hardstop: https://prover.certora.com/output/3106/2a226fc88e9b4ce181ac722491ab171f/?anonymousKey=b59ba71ef211d785f9baa02e05854d68af4a6e86
# certoraRun certora/confs_for_CI/OperatorRegistryV1_1.conf --rule validatorStateTransition_2in_M15 --msg "validatorStateTransition_2in_M15"    # hardstop: https://prover.certora.com/output/3106/ffc62542d5214d08bd74eea6d06cb810/?anonymousKey=b2f05081e09aed4f6651b678cc5bb8971acfb071
# certoraRun certora/confs_for_CI/OperatorRegistryV1_1.conf --rule validatorStateTransition_3in_M15 --msg "validatorStateTransition_3in_M15"    # hardstop: https://prover.certora.com/output/3106/ee7505e8da984b5a9e324c3828c80ef7/?anonymousKey=331273aa73a0dacd4faaa2baf4b94dc0a1ed60e3
# certoraRun certora/confs_for_CI/OperatorRegistryV1_1.conf --rule whoCanDeactivateOperator_LI4 --msg "whoCanDeactivateOperator_LI4"            # hardstop: https://prover.certora.com/output/3106/87a6ff6f03bb4702ad41e7a3f5921f64/?anonymousKey=465005af54c7cd8fc1cf2c6797106fbdcf78cdd8






# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf 
# hardstop with 4 loops: https://prover.certora.com/output/3106/486a4f6d737d4dcdb404707b53dbe2d6/?anonymousKey=128b33eec2e578ae678ff5186977c7af3b5625ac

# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf 
# running with 2 loops: sanity issues with 2 loops: https://prover.certora.com/output/3106/d158ba77bdcc4b4288fb17958d8b6a8b/?anonymousKey=722a4b01d9a0e9fc8e80ce92634c869f06573a10
# only validatorStateTransition_3_4_M13 passed

# running separately with 4 loops
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_0in_M16 --msg "validatorStateTransition_0in_M16" # passes (40 mins): https://prover.certora.com/output/3106/8ae7d88be2304296be1a1c665e8af52e/?anonymousKey=d3c7ab7c1ebfc6d7cae358f8df7e0d9fece288cb
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_1in_M16 --msg "validatorStateTransition_1in_M16" # passes (60 mins): https://prover.certora.com/output/3106/0eb34b58b5124581a202e3265f73f589/?anonymousKey=42dfdbcc79a7f3df44c291cbc54c48f53ea03bbf
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_2in_M16 --msg "validatorStateTransition_2in_M16" # hardstop: https://prover.certora.com/output/3106/97b6af049a1b4be8a52c4380f8c9eb2c/?anonymousKey=4b6b2cfdbd324e346b49075fdc6147294f41df92
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_3_4_M13 --msg "validatorStateTransition_3_4_M13" # passes (100 mins): https://prover.certora.com/output/3106/d2ec7af61b524e3a9ab2dafc15c004a7/?anonymousKey=9e82deb651af6fc4bb00f9a753037a6b4d134baa
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_3_4_M16 --msg "validatorStateTransition_3_4_M16" # hardstop:: https://prover.certora.com/output/3106/0376d04c14dc473f94484d98f224bee2/?anonymousKey=090ce6f65a1dd14aa169e5f3ffa96a9ba21b210d
# certoraRun certora/confs_for_CI/OperatorRegistryV1_2.conf --rule validatorStateTransition_3in_M16 --msg "validatorStateTransition_3in_M16" # timeout/hardstop: https://prover.certora.com/output/3106/42815846a3d8457c9552e289e83b6404/?anonymousKey=0271c6cd811681e807bf17167a3072cea979ba64






# loop iter 2, cache none, rule sanity basic
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule exitingValidatorsDecreasesDiscrepancy --msg "exitingValidatorsDecreasesDiscrepancy"                      # hardstop: https://prover.certora.com/output/3106/2159b9a95b5c4d08a9bc026beed72a72/?anonymousKey=201d98ee748a74e4a315b72587e26df3f53f9849
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule fundedAndExitedCanOnlyIncrease_IL2 --msg "fundedAndExitedCanOnlyIncrease_IL2"                            # hardstop: https://prover.certora.com/output/3106/8203be3ceacb40d8bc7f942bdf002873/?anonymousKey=149a78eb33ce85085ae789044f1908c37eaaa3ef
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule fundedAndExitedCanOnlyIncrease_IL4 --msg "fundedAndExitedCanOnlyIncrease_IL4"                            # sanity: https://prover.certora.com/output/3106/2aadbd08ce214af5b0e5e85629479340/?anonymousKey=269045317b271fe73b5fd439a81ea4d2802886d6
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule fundedAndExitedCanOnlyIncrease_removeValidators --msg "fundedAndExitedCanOnlyIncrease_removeValidators"  # hardstop: https://prover.certora.com/output/3106/8a20a879eb804017bb53390ddd3ba815/?anonymousKey=a306c9fe7700cac46b01a5706a18beb8e5dda656
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule fundedKeysCantBeChanged --msg "fundedKeysCantBeChanged"                                                  # hardstop: https://prover.certora.com/output/3106/3341d89961a94b7a8720a8ad780351bf/?anonymousKey=8af1c7b7ae7b6ad2f34e46794feaf3145d215b9d
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule fundedValidatorCantBeRemoved --msg "fundedValidatorCantBeRemoved"                                        # hardstop: https://prover.certora.com/output/3106/a945cb3b09db4a4fb534c5787ac4d16a/?anonymousKey=3e3b13bdd952c402a0cda417e69ba6f2f7043b5b
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule removeValidatorsDecreaseKeys --msg "removeValidatorsDecreaseKeys"                                        # hardstop: https://prover.certora.com/output/3106/5ec1b882038948898d0dc16a35ef93ce/?anonymousKey=042822e40f8e8c799daca3bea3830548d712622b
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule startingValidatorsDecreasesDiscrepancy --msg "startingValidatorsDecreasesDiscrepancy"                    # verified: https://prover.certora.com/output/3106/593c50b7ddd34ebda7730935b6a77959/?anonymousKey=937a2c19bd7365c1316648a522d72ccb3d9c4c2a
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_0in_M9 --msg "validatorStateTransition_0in_M9"                                  # hardstop: https://prover.certora.com/output/3106/ea82f886aa764a28ba43ebc603fe8dd6/?anonymousKey=c9ce243ba08884049cddf9d08835ea64a11de19c
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_0in_index --msg "validatorStateTransition_0in_index"                            # hardstop: https://prover.certora.com/output/3106/3a4321074e8b4b1083ddde0db142da4d/?anonymousKey=65a4072bf8e2d5f877c3161a772b6ddb063dfc6e
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_1in_M9 --msg "validatorStateTransition_1in_M9"                                  # verified: https://prover.certora.com/output/3106/eeb8d692f6b4443fbcf70d0aa67525e1/?anonymousKey=70c513ee69132ac42d765e8fffe6273eb340f2af
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_1in_index --msg "validatorStateTransition_1in_index"                            # hardstop: https://prover.certora.com/output/3106/e299c91ea94d47898efbd7b0fd3e506d/?anonymousKey=15f996a973d8132731ba297a5ebc2e8d351de227
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_2_1_index_limit --msg "validatorStateTransition_2_1_index_limit"                # sanity: https://prover.certora.com/output/3106/b757270b60fd4a8bb3b65ccc141caac8/?anonymousKey=8a2154f02356930c0429a4f72c1c4ddbbd56bda6
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_2in_M9 --msg "validatorStateTransition_2in_M9"                                  # hardstop: https://prover.certora.com/output/3106/7c859bc128bd4421a5335ef3b8aca4b8/?anonymousKey=05c71074bf4b72b82b4811bfb8efbbf534884657
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_2in_index --msg "validatorStateTransition_2in_index"                            # hardstop: https://prover.certora.com/output/3106/15800711a6644e23b1f24f4e85b21c53/?anonymousKey=64ddc692d4f416655e731c8b86d23df1c875a587
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_2 --msg "validatorStateTransition_3_2"                                        # hardstop: https://prover.certora.com/output/3106/57c9a4ee476c4e7dbbd017a6454a68d9/?anonymousKey=97b0f98ac91db6ef10e0657f2dec585387e4bb9b
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_4_M10 --msg "validatorStateTransition_3_4_M10"                                # verified: https://prover.certora.com/output/3106/543205d90cbd4e76a51c0ca09e76ae36/?anonymousKey=99b9e1bec26c20533300c9f011a2ed79c245d18d
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_4_M12 --msg "validatorStateTransition_3_4_M12"                                # verified: https://prover.certora.com/output/3106/cabfa16f990a4dbda799aff543113c9b/?anonymousKey=7ff330decaf6f8a1de0f7cd2ed0a3ee7dbc597d9
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_4_M14 --msg "validatorStateTransition_3_4_M14"                                # verified: https://prover.certora.com/output/3106/c010e624933b4d79a903751b34ebcc7e/?anonymousKey=43bcc256e775ab276121ea5516d391d9bf46ac40
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_4_M7 --msg "validatorStateTransition_3_4_M7"                                  # verified: https://prover.certora.com/output/3106/f08a3dba3fbc4d31b4215b9da8b620b2/?anonymousKey=80ced468e124136325095c3cfbd8bc605c73ad57
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3_4_M9 --msg "validatorStateTransition_3_4_M9"                                  # hardstop: https://prover.certora.com/output/3106/acda4f0026d14b14bc9de2c000f84c0b/?anonymousKey=ef0898f00a39bb39fa90710474e81440d228ebf6
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3in_M9 --msg "validatorStateTransition_3in_M9"                                  # hardstop: https://prover.certora.com/output/3106/6408a504419f4ef2a7fcd7077c14b8d1/?anonymousKey=6f43c0ebe38859beef5ac64336ab5311292fae5c
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_3in_index --msg "validatorStateTransition_3in_index"                            # hardstop: https://prover.certora.com/output/3106/fbedf697c7964928be29f5e5f2634400/?anonymousKey=cad8a4a628e084b2ba071fa93482d92010e45e4c
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M10 --msg "validatorStateTransition_4_3_M10"                                # verified: https://prover.certora.com/output/3106/f17a6acefcf34f86a29def0d70c229a8/?anonymousKey=562cf655fd712f52c1ed67317c68a24f618eda70
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M12 --msg "validatorStateTransition_4_3_M12"                                # verified: https://prover.certora.com/output/3106/9812bfd5788542a3a7bd179bc88c761b/?anonymousKey=6d7a1e583880b622dec72c8bd50c0eb84cc5fe33
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M13 --msg "validatorStateTransition_4_3_M13"                                # verified: https://prover.certora.com/output/3106/51d5be057aa840efab7399007b49a390/?anonymousKey=b02b5c113babd242373699237e17aacd9a2851f2
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M14 --msg "validatorStateTransition_4_3_M14"                                # verified: https://prover.certora.com/output/3106/d8f176d5398f4da1ae17e85986d5def8/?anonymousKey=4077b91ce8f1b063650e822ad061913059f404cb
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M15 --msg "validatorStateTransition_4_3_M15"                                # hardstop: https://prover.certora.com/output/3106/eb5b935da550444c8a6ebac48fe99b5a/?anonymousKey=59878d14d4adb3090c25f2b5f70fad552cc90983
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M7 --msg "validatorStateTransition_4_3_M7"                                  # verified: https://prover.certora.com/output/3106/93d3ef37ae22440fa53ea1e0f2183207/?anonymousKey=83260f93072d6a38358e34875b403fdf94ce9dc1
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4_3_M9 --msg "validatorStateTransition_4_3_M9"                                  # hardstop: https://prover.certora.com/output/3106/508cb0bfc8624d02b5b64f34983f64d8/?anonymousKey=fc7ffc14f4058b4e294078142fa0b382bcf75b2f
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4in_M9 --msg "validatorStateTransition_4in_M9"                                  # hardstop: https://prover.certora.com/output/3106/b7d668634c354e3093194a77bfd5972f/?anonymousKey=c14fdc015ab621c0fd23c1d40f9d2f046f4541f5
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule validatorStateTransition_4in_index --msg "validatorStateTransition_4in_index"                            # hardstop: https://prover.certora.com/output/3106/bb60fb8b96194f209efcdc4544e59c7c/?anonymousKey=b841ce92df4a4a075204459c5b5cbcc138520ddf
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule whoCanChangeOperatorsCount_IL2 --msg "whoCanChangeOperatorsCount_IL2"                                    # sanity: https://prover.certora.com/output/3106/b7b63143c0e443a1a48bd78cd3ab95d7/?anonymousKey=ca747789e79450920ab30633450a44665067f5ba
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule whoCanChangeValidatorsCount --msg "whoCanChangeValidatorsCount"                                          # hardstop: https://prover.certora.com/output/3106/33e7c771fb964c0eae884faf599797db/?anonymousKey=f00ac3723c268129535ec810ade560179a20c0a0
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule whoCanDeactivateOperator_LI2 --msg "whoCanDeactivateOperator_LI2"                                        # hardstop: https://prover.certora.com/output/3106/b0d2edc82a10441eb47c7201efa9fb34/?anonymousKey=1edf3645c14909ec7e8e725aa831ded0b8e29879
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule witness4_3ExitingValidatorsDecreasesDiscrepancy --msg "witness4_3ExitingValidatorsDecreasesDiscrepancy"  # hardstop: https://prover.certora.com/output/3106/05b3f81841944f7cabbab384500a1f16/?anonymousKey=aae727fbff3d3af0ca7f8d74798c30f6167e6648
# certoraRun certora/confs_for_CI/OperatorRegistryV1_3.conf --rule witness4_3StartingValidatorsDecreasesDiscrepancy --msg "witness4_3StartingValidatorsDecreasesDiscrepancy" # violation: https://prover.certora.com/output/3106/8ae1c0683a1148558ec9e6f1337e5546/?anonymousKey=501ad492654df33d41c82fa69d308c953532d689






# ignore for now:
# certoraRun certora/confs_for_CI/OperatorRegistryV1_31.conf
# certoraRun certora/confs_for_CI/OperatorRegistryV1_32.conf # good with 2 loops: https://prover.certora.com/output/3106/b5e3055cb54e492bacefe0e267c7780f/?anonymousKey=667e9fb4231e637553c5fd44812d02d6322df8d2
# certoraRun certora/confs_for_CI/OperatorRegistryV1_33.conf
# certoraRun certora/confs_for_CI/OperatorRegistryV1_34.conf # good with 2 loops: https://prover.certora.com/output/3106/4bb378277da4449fa9062b4ec858a6d0/?anonymousKey=a36c270ecae5921b89aa562f93c9f074fc534e87
# certoraRun certora/confs_for_CI/OperatorRegistryV1_35.conf