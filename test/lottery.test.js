const Lottery = artifacts.require("Lottery");
const expectEvent = require("./expectEvent");
const assertRevert = require("./assertRevert");
const { assert } = require("chai");

contract("Lottery", function ([deployer, user1, user2]) {
    let lottery;
    let betAmount = 5 * 10 ** 15;
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

    describe.only("isMatch", function () {
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
