const Lottery = artifacts.require("Lottery");

contract("Lottery", function ([deployer, user1, user2]) {
  let lottery;

  // 테스트 전에 미리 실행 하는 함수
  beforeEach(async () => {
    console.log("Basic Test");
    lottery = await Lottery.new(); // 스마트 컨트랙트 배포
  });

  // only 입력시 요것만 테스트를 해본다.
  it("Getpot should return current pot", async () => {
    console.log("Getpot should return current pot");
    let pot = await lottery.getPot();

    assert.equal(pot, 0);
  });
});
