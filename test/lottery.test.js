const Lottery = artifacts.require("Lottery");
const expectEvent = require("./expectEvent");
const assertRevert = require("./assertRevert");
const { assert } = require("chai");

contract("Lottery", function ([deployer, user1, user2]) {
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let betAmountBN = new web3.utils.BN(betAmount.toString());
    let BET_BLOCK_INTERVAE = 3;

    // 테스트 전에 미리 실행 하는 함수
    beforeEach(async () => {
        lottery = await Lottery.new(); // 스마트 컨트랙트 배포
    });

    // only 입력시 요것만 테스트를 해본다.
    it("Getpot should return current pot", async () => {
        console.log("Getpot should return current pot");
        let pot = await lottery.getPot();

        assert.equal(pot, 0);
    });

    describe("Bet", function () {
        it("should fail when the bet money is not 0.005 ETH", async () => {
            // fail transaction
            await assertRevert(
                lottery.bet("0xab", { from: user1, value: betAmount })
            );
            // await lottery.bet('0xab', {from:user1, value:betAmount})

            // ethereum transaction object {chainId, value, to, from, gas(limit), gasPrice}
        });

        it("should put the bet to the bet queue with 1 bet", async () => {
            // bet
            const receipt = await lottery.bet("0xab", {
                from: user1,
                value: betAmount,
            });
            console.log(receipt);
            console.log(
                `receipt logs.args : ${JSON.stringify(receipt.logs[0].args)}`
            );

            let pot = await lottery.getPot();
            assert.equal(pot, 0);
            // check contract Balance == 0.005 ETH
            let contractBalance = await web3.eth.getBalance(lottery.address);
            assert.equal(contractBalance, betAmount);

            // check bet info
            let currentBlockNumber = await web3.eth.getBlockNumber();
            let bet = await lottery.getBetInfo(0);
            assert.equal(
                bet.answerBlockNumber,
                currentBlockNumber + BET_BLOCK_INTERVAE
            );
            assert.equal(bet.bettor, user1);
            assert.equal(bet.challenges, "0xab");

            // check log
            await expectEvent.inLogs(receipt.logs, "BET");
        });
    });

    describe("Distribute", function () {
        describe("When the answer is checkable", function () {
            it("should give the user the pot when the answer matches", async () => {
                // 두글자 다 맞혔을 때
                // betAndDistribute 여러번 발생(pot 머니 높이기 위해서)
                await lottery.setAnswerForTest(
                    "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9",
                    { from: deployer }
                );
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 1 => 4
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 2 => 5
                await lottery.betAndDistribute("0xab", {
                    from: user1,
                    value: betAmount,
                }); // block 3 => 6
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 4 => 7
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 5 => 8
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 6 => 9

                const potBefore = await lottery.getPot(); // Pot : 0.01ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);

                // 3번 블럭에서 생성한 트랜잭션이 7번블럭은 와야 정답 체크 가능
                const receipt7 = await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 7 => 10

                const potAfter = await lottery.getPot(); // Pot : 0.00 ETH
                const user1BalanceAfter = await web3.eth.getBalance(user1); // Before + 0.015ETH

                // pot 머니 변화 확인
                assert.equal(
                    potBefore.toString(),
                    new web3.utils.BN((betAmount * 2).toString())
                );
                assert.equal(
                    potAfter.toString(),
                    new web3.utils.BN((0).toString())
                );

                // user(winner)의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(
                    user1BalanceBefore
                        .add(potBefore)
                        .add(betAmountBN)
                        .toString(),
                    new web3.utils.BN(user1BalanceAfter).toString()
                );
            });
            it("should give the user the amount he or she bet when a single character matches", async () => {
                // 한글자만 맞혔을 때
                // betAndDistribute 여러번 발생(pot 머니 높이기 위해서)
                await lottery.setAnswerForTest(
                    "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9",
                    { from: deployer }
                );
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 1 => 4
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 2 => 5
                await lottery.betAndDistribute("0xaa", {
                    from: user1,
                    value: betAmount,
                }); // block 3 => 6
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 4 => 7
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 5 => 8
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 6 => 9

                const potBefore = await lottery.getPot(); // Pot : 0.01ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);

                // 3번 블럭에서 생성한 트랜잭션이 7번블럭은 와야 정답 체크 가능
                const receipt7 = await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 7 => 10

                const potAfter = await lottery.getPot(); // Pot : 0.10 ETH
                const user1BalanceAfter = await web3.eth.getBalance(user1); // Before + 0.005ETH

                // pot 머니 변화 확인
                assert.equal(
                    potBefore.toString(),
                    new web3.utils.BN((betAmount * 2).toString())
                );
                assert.equal(
                    potAfter.toString(),
                    new web3.utils.BN((betAmount * 2).toString())
                );

                // user의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(
                    user1BalanceBefore.add(betAmountBN).toString(),
                    new web3.utils.BN(user1BalanceAfter).toString()
                );
            });
            it("should get the eth of user when the answer does not match at all", async () => {
                // 둘다 틀렸을 때
                // betAndDistribute 여러번 발생(pot 머니 높이기 위해서)
                await lottery.setAnswerForTest(
                    "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9",
                    { from: deployer }
                );
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 1 => 4
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 2 => 5
                await lottery.betAndDistribute("0x11", {
                    from: user1,
                    value: betAmount,
                }); // block 3 => 6
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 4 => 7
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 5 => 8
                await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 6 => 9

                const potBefore = await lottery.getPot(); // Pot : 0.01ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);

                // 3번 블럭에서 생성한 트랜잭션이 7번블럭은 와야 정답 체크 가능
                const receipt7 = await lottery.betAndDistribute("0x11", {
                    from: user2,
                    value: betAmount,
                }); // block 7 => 10

                const potAfter = await lottery.getPot(); // Pot : 0.01 ETH
                const user1BalanceAfter = await web3.eth.getBalance(user1); // Before와 동일

                // pot 머니 변화 확인
                assert.equal(
                    potBefore.toString(),
                    new web3.utils.BN((betAmount * 2).toString())
                );
                assert.equal(
                    potAfter.toString(),
                    new web3.utils.BN((betAmount * 3).toString())
                );

                // user(winner)의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(
                    user1BalanceBefore.toString(),
                    new web3.utils.BN(user1BalanceAfter).toString()
                );
            });
        });

        describe("When the answer is not revealed(Not Mined)", function () {});

        describe("When the answer is not revealed(Block limit is passed)", function () {});
    });

    describe("isMatch", function () {
        let blockHash =
            "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9";

        it("should be BettingResult.Win when two characters match", async () => {
            let blockHash =
                "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9";
            let matchingResult = await lottery.isMatch("0xab", blockHash);
            assert.equal(matchingResult, 1);
        });
        it("should be BettingResult.Fail when two characters match", async () => {
            let matchingResult = await lottery.isMatch("0xcd", blockHash);
            assert.equal(matchingResult, 0);
        });
        it("should be BettingResult.Draw when two characters match", async () => {
            let blockHash =
                "0xab190e5ac5a24a44bac86107b815f6510eafe9ed10bf4628d62e1cd8343d2b9";
            let matchingResult = await lottery.isMatch("0xaa", blockHash);
            assert.equal(matchingResult, 2);
        });
    });
});
