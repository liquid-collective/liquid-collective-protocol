#! /bin/bash

rm vestingPostGo.csv

echo "start,end,cliffDuration,lockDuration,duration,periodDuration,amount,creator,beneficiary,revocable,releasedAmount,ignoreGlobalLock" >> vestingPostGo.csv

for i in {0..66}
do
    cast call 0xb2f102b87022bf5a64e012b39FF25a404102e301 "getVestingSchedule(uint256)(uint64,uint64,uint32,uint32,uint32,uint32,uint256,address,address,bool,uint256)" $i  --rpc-url $RPCG | tr '\n' ',' >> vestingPostGo.csv
    cast call 0xb2f102b87022bf5a64e012b39FF25a404102e301 "isGlobalUnlockedScheduleIgnored(uint256)(bool)" $i  --rpc-url $RPCG >> vestingPostGo.csv
done