#! /bin/bash

rm vestingPost.csv

echo "start,end,cliffDuration,lockDuration,duration,periodDuration,amount,creator,beneficiary,revocable,releasedAmount,ignoreGlobalLock" >> vestingPost.csv

for i in {0..66}
do
    cast call 0xb5Fe6946836D687848B5aBd42dAbF531d5819632 "getVestingSchedule(uint256)(uint64,uint64,uint32,uint32,uint32,uint32,uint256,address,address,bool,uint256)" $i | tr '\n' ',' >> vestingPost.csv
    cast call 0xb5Fe6946836D687848B5aBd42dAbF531d5819632 "isGlobalUnlockedScheduleIgnored(uint256)(bool)" $i >> vestingPost.csv
done