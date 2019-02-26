# Notes

RBT Tree
- Removing inserted, removed and additional function

Before

rbtLibTx status=0x1 Success gas=3000000 gasUsed=956302 costETH=0.00478151 costUSD=0.6498550241 @ ETH/USD=135.91 gasPrice=5 gwei block=256 txIx=0 txId=0xe86939373e5798a6bfb72799a171ce12a1327c63cd2981f8a63741d6eb9eee5a @ 1550932918 Sat, 23 Feb 2019 14:41:58 UTC
dexzTx status=0x1 Success gas=6400000 gasUsed=6164352 costETH=0.03082176 costUSD=4.1889854016 @ ETH/USD=135.91 gasPrice=5 gwei block=258 txIx=0 txId=0xb6f74e808dadb13b4f8d29eaedad394e3db5aab218e0a938c90318695ccf1022 @ 1550932920 Sat, 23 Feb 2019 14:42:00 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=597253 costETH=0.002986265 costUSD=0.40586327615 @ ETH/USD=135.91 gasPrice=5 gwei block=273 txIx=0 txId=0x780cb3b614d066bb1c5b9a3a9bca4ca9c6c0d447859d8ea145efee1cf63c0d79 @ 1550932935 Sat, 23 Feb 2019 14:42:15 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=679864 costETH=0.00339932 costUSD=0.4620015812 @ ETH/USD=135.91 gasPrice=5 gwei block=278 txIx=0 txId=0xb9d31d617e3c894ff384106eaa653989b851b05e8f667ded7cb81c80ad10e855 @ 1550932940 Sat, 23 Feb 2019 14:42:20 UTC
approveAndCall1_1Tx status=0x1 Success gas=2000000 gasUsed=533972 costETH=0.00266986 costUSD=0.3628606726 @ ETH/USD=135.91 gasPrice=5 gwei block=284 txIx=0 txId=0x009866ca64206b5546cee99ccbb9630c8556430f369fb87c68af1ad611a1ab55 @ 1550932946 Sat, 23 Feb 2019 14:42:26 UTC

After SKINNY

rbtLibTx status=0x1 Success gas=3000000 gasUsed=948931 costETH=0.004744655 costUSD=0.64484606105 @ ETH/USD=135.91 gasPrice=5 gwei block=2937 txIx=0 txId=0x6f7ca956dbf5cd10f0f74d8901a00b45eb4c91a5607ef2d0ff44f38ab093cfb4 @ 1550963084 Sat, 23 Feb 2019 23:04:44 UTC
dexzTx status=0x1 Success gas=6400000 gasUsed=6131157 costETH=0.030655785 costUSD=4.16642773935 @ ETH/USD=135.91 gasPrice=5 gwei block=2939 txIx=0 txId=0x9afd8c221f6ae22692e0b2bafd517e20613f8292313921b3582c6f6efabb0ac5 @ 1550963086 Sat, 23 Feb 2019 23:04:46 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=577123 costETH=0.002885615 costUSD=0.39218393465 @ ETH/USD=135.91 gasPrice=5 gwei block=2952 txIx=0 txId=0x79f23bd2e8473c6aaed2aaa046bf31e9a00219ec38f7d13a8ec38cb88175bf63 @ 1550963099 Sat, 23 Feb 2019 23:04:59 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=639489 costETH=0.003197445 costUSD=0.43456474995 @ ETH/USD=135.91 gasPrice=5 gwei block=2957 txIx=0 txId=0x01f95ba97c093ad6ae5d5ddbfa1b90d712a6040d529e3d27476c9d0ca9fdaa28 @ 1550963104 Sat, 23 Feb 2019 23:05:04 UTC
approveAndCall1_1Tx status=0x1 Success gas=2000000 gasUsed=508466 costETH=0.00254233 costUSD=0.3455280703 @ ETH/USD=135.91 gasPrice=5 gwei block=2962 txIx=0 txId=0xd14c14b52de536296627c2e67916d205723a373d2303e50f68e2adde6db20d4e @ 1550963109 Sat, 23 Feb 2019 23:05:09 UTC

After SKINNY2

rbtLibTx status=0x1 Success gas=3000000 gasUsed=948931 costETH=0.004744655 costUSD=0.64484606105 @ ETH/USD=135.91 gasPrice=5 gwei block=10689 txIx=0 txId=0x05eba2cf99ffb4fe00ecf61d28554080bda05801706c71062b8c34212ba4d101 @ 1550970836 Sun, 24 Feb 2019 01:13:56 UTC
dexzTx status=0x1 Success gas=6400000 gasUsed=6074856 costETH=0.03037428 costUSD=4.1281683948 @ ETH/USD=135.91 gasPrice=5 gwei block=10691 txIx=0 txId=0x09f205208c8c62c64b47a25a2ac989ab99e558fc8eb70896600ceb37219aa60a @ 1550970838 Sun, 24 Feb 2019 01:13:58 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=534655 costETH=0.002673275 costUSD=0.36332480525 @ ETH/USD=135.91 gasPrice=5 gwei block=10705 txIx=0 txId=0xdc9ae33b97381deb9f1cf913830ee47f175065795b5d088f71dc8c0f9cc267b2 @ 1550970852 Sun, 24 Feb 2019 01:14:12 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=592192 costETH=0.00296096 costUSD=0.4024240736 @ ETH/USD=135.91 gasPrice=5 gwei block=10710 txIx=0 txId=0xb49a018f9d6cbfaf83804e854a3af9aaf9be4f9de06565db107f99955596d468 @ 1550970857 Sun, 24 Feb 2019 01:14:17 UTC
approveAndCall1_1Tx status=0x1 Success gas=2000000 gasUsed=507143 costETH=0.002535715 costUSD=0.34462902565 @ ETH/USD=135.91 gasPrice=5 gwei block=10716 txIx=0 txId=0x14a2381ae133a8306335362a45bedb1985518b18e52e835161626e0bb517373f @ 1550970863 Sun, 24 Feb 2019 01:14:23 UTC

After last(), prev() and exist()

rbtLibTx status=0x1 Success gas=3000000 gasUsed=948867 costETH=0.004744335 costUSD=0.64480256985 @ ETH/USD=135.91 gasPrice=5 gwei block=35895 txIx=0 txId=0x2f0efc2140cb6a6affa5ab0de57435e4fe5a32baea1e879059a731da5309c996 @ 1551000647 Sun, 24 Feb 2019 09:30:47 UTC
dexzTx status=0x1 Success gas=6400000 gasUsed=6055735 costETH=0.030278675 costUSD=4.11517471925 @ ETH/USD=135.91 gasPrice=5 gwei block=35897 txIx=0 txId=0x58f30e9b246a2297b6914aa992353253f13039a3f58784910cc63930f8a97b17 @ 1551000649 Sun, 24 Feb 2019 09:30:49 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=534915 costETH=0.002674575 costUSD=0.36350148825 @ ETH/USD=135.91 gasPrice=5 gwei block=35910 txIx=0 txId=0x27c7fc9dcf27da04494e9d506d0b457b8ba6fca6b4de4d739b963c45f3e4b053 @ 1551000662 Sun, 24 Feb 2019 09:31:02 UTC
ordersTx[0] status=0x1 Success gas=3000000 gasUsed=592416 costETH=0.00296208 costUSD=0.4025762928 @ ETH/USD=135.91 gasPrice=5 gwei block=35915 txIx=0 txId=0xe26da289db704bc3ae803d68feedd7d89a12accbe0c1d8d380827a0a7aef3c8d @ 1551000667 Sun, 24 Feb 2019 09:31:07 UTC
approveAndCall1_1Tx status=0x1 Success gas=2000000 gasUsed=507367 costETH=0.002536835 costUSD=0.34478124485 @ ETH/USD=135.91 gasPrice=5 gwei block=35920 txIx=0 txId=0x61ea290c91af5703e0bfd30ad24489982c8b22c364e5ea2d884c7f875005c571 @ 1551000672 Sun, 24 Feb 2019 09:31:12 UTC
