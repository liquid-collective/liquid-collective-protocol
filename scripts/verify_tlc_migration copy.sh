#! /bin/bash

rm vestinggo.csv

echo "start,end,cliffDuration,lockDuration,duration,periodDuration,amount,creator,beneficiary,revocable,releasedAmount" >> vestinggo.csv

for i in {0..66}
do
    cast call 0xb2f102b87022bf5a64e012b39FF25a404102e301 "getVestingSchedule(uint256)(uint64,uint64,uint32,uint32,uint32,uint32,uint256,address,address,bool,uint256)" $i --rpc-url $RPCG | tr '\n' ',' | sed 's/,$//g' >> vestinggo.csv
    echo "\n" >> vestinggo.csv
done