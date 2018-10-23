#!/bin/bash

#
# Executed hourly by cron
#

pushd ${BASH_SOURCE%/*} > /dev/null

RUNTIME=3600 ./tweet_filter.sh 'dkpol,kv17,dkmedier,zentropa,fuldskæg,dkgreen,eudk,sundpol,tv17,kompoldk,dkøko,kbhpol,dksocial,zentropa,danmark,detkuhaværetmig,skolechat,demokratietsaften,uddpol,skattely,dkenergi,ulighed,vækst,velfærd,arbejde,dkcivil,denmark,spinalarm,somedk,ligestilling,ligeløn,dkaid,dkfinans,nyheder,dkoeko,medienyt,overvågning,socialkontrol,stopdigselv,nytår,dkklima,udflytning,hykleri,Århus,aarhus,dknatur,ytringsfrihed,peberspray,kvotekonge,kvotekonger,prinshenrik,SomaliskBerigelse,ok18,twitterhjerne,enloesningforalle,enløsningforalle,kattegatbro,vildsvinehegn,nokernok,kapsejlads,kapsejladsen' 'dktags' < /dev/null >> tweet_filter.log 2>> tweet_filter.log &

RUNTIME=3600 ./tweet_follow.sh 'DEADLINE,ForBarnet,Fedeabe,peterfalktoft,lasserimmer,vestager,tv2newsdk,LukasGraham,politiken,OnFireAnders,DRNyheder,larsloekke,informeren,drp3,gmitchew,R4nd4hl,pomaEB,alternativet_,BosseStine,SusanPetrea,sorenpind,cekicozlem,pelledragsted,larskohler,peterfalktoft,MargueritteEch,tv2politik,DavidTrads,jyllandsposten,tv2newsdk,minkonto,radikale,nikogrunfeld,askrost,annette_benette,skaarup_df,oestergaard,_Frederik_Dahl_,birtheskyt,BEsbensen,venstredk,regeringDK,HoghSorensen,afriishansen,PHummelgaard,karmel80,Steensc,RasmusJarlov ' 'dk'  < /dev/null >> tweet_filter.log 2>> tweet_follow.log &

