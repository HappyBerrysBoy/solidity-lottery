pragma solidity >=0.4.21 < 0.6.0;

contract Lottery{
  struct BetInfo {
    uint256 answerBlockNumber;
    address payable bettor;     // 코인 전송을 위해서는 변수 앞에 payable을 써줘야함
    byte challenges;    // ex:0xab
  }

  enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
  enum BettingResult {Fail, Win, Draw}

  // gas 관련 정보
  // gas(gasLimit와 동일한 의미) : 단위가 없는 숫자
  // gasPrice(wei단위를 쓰지만 너무 적은 단위이기 때문에 gwei(10 ** 9) 단위로 많이 쓴다.)
  // ETH : 1 ETH = 10 ** 18 wei
  // 수수료 = gas(21000) * gasPrice(gwei 단위(1gwei == 10 ** 9wei))
  

  // public 으로 전역변수 설정시 자동으로 getter을 만들어 준다
  // smart contract 외부에서 오너 확인 가능하다고 함
  address payable public owner;
  uint256 private _tail;
  uint256 private _head;
  // _bets 변수에 베팅된 값들을 저장, 위에 선언된 _tail 값을 증가시키면서 저장하고, _head 값으로 베팅값을 검증한다
  mapping (uint256 => BetInfo) private _bets;   

  // 베팅머니는 0.005ETH로 설정
  // 1 * 10 ** 18 => 1ETH, 이므로 5 * 10 ** 15가 0.005
  uint256 constant internal BET_AMOUNT = 5 * 10 ** 15;    
  uint256 constant internal BET_BLOCK_INTERVAL = 3;     // 몇 번째 뒤의 블럭을 찾을 것인가
  uint256 constant internal BLOCK_LIMIT = 256;

  uint256 private _pot;
  bool private mode = false;  // false : use answer for teset, true : real block hash 
  bytes32 answerForTest;

  event BET(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);
  event WIN(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
  event FAIL(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
  event DRAW(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
  event REFUND(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);

  constructor() public {
    owner = msg.sender; // 21000GAS * gasPrice
  }

  // view는 smartcontract에 저장된 값에 접근 시 사용
  // pure는 컨트랙 접근 없이 사용 가능함 함수
  function getPot() public view returns(uint256 pot){
    return _pot;
  }

  /**
    * @dev 베팅과 정답체크를 한다.
    * @param challenges 유저가 베팅하는 글자
    * @return 함수가 잘 수행 되었는지 확인하는 boolean값
   */
  function betAndDistribute(byte challenges) public payable returns (bool result){
    bet(challenges);

    distribute();

    return true;
  }

  // Bet
  // 베팅 참여(코인 전송이 필요하므로 payable 추가)
  /**
    * @dev 베팅을 한다. 유저는 0.005이더를 보내야 하고, 베팅용 1byte 글자를 보낸다.
    * 큐에 저장된 베팅 정보는 이후 distribute 함수에서 해결된다.
    * @param challenges 유저가 베팅하는 글자
    * @return 함수가 잘 수행 되었는지 확인하는 boolean값
   */
  function bet(byte challenges) public payable returns (bool result) {
    // check the proper ether is sent
    require(msg.value == BET_AMOUNT, "Not enough ETH");

    // push bet to the queue
    require(pushBet(challenges), "Fail to add a new Bet Info");

    // emit event
    emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);

    return true;
  }
  // _bets 값에다가 베팅 정보 저장

  // Distribute
  /**
    * @dev 베팅결과값을 확인하고 팟머니를 분배
    * 정답 실패:팟머니 축적, 맞춤 : 팟머니 획득, 한글자 맞춤 : 베팅금액만 반환, 정답확인 불가 : 베팅 금액만 반환
   */
  function distribute() public {
    // 큐에 저장된 베팅 정보가 (head)3, 4, 5, 6, 7, 8, 9, 10(tail)
    // 큐 순서대로 값들을 체크하고, 2자리 모두 맞힌 경우 팟머니를 전송,
    // 1자리만 맞힌 경우 건 값만 돌려줌
    uint256 cur;
    uint256 transferAmount;
    BetInfo memory b;
    BlockStatus currentBlockStatus;
    BettingResult currentBettingResult;

    for(cur=_head; cur<_tail; cur++){
      b = _bets[cur];
      currentBlockStatus = getBlockStatus(b.answerBlockNumber);
      
      // checkable : 블럭 넘버가 정답 블럭보다 커야하고, 블럭.number < BLOCK_LIMIT(256) + AnswerBlockNumber 
      if(currentBlockStatus == BlockStatus.Checkable){
        bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
        currentBettingResult = isMatch(b.challenges, answerBlockHash);
        // if win, bettor gets pot
        if(currentBettingResult == BettingResult.Win){
          uint256 tmpPot = _pot;  // 총 수량 임시 저장

          // pot = 0, pot을 0으로 만드는 작업을 가장 먼저 하는 것이 좋다. 
          // 그렇지 않으면 전송되는 동안 _pot 값이 아직 0이 안된 상태라서 무슨 일이 생길지.!!
          _pot = 0;

          // transfer pot money
          transferAmount = transferAfterPayingFee(b.bettor, tmpPot + BET_AMOUNT);
          
          // emit win event
          emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
        }

        // if fail, bettor's money goes pot
          if(currentBettingResult == BettingResult.Fail){
          // pot = pot + BET_AMOUNT
          _pot += BET_AMOUNT;
          // emit fail event
          emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
        }

        // if draw, refund bettor's money
          if(currentBettingResult == BettingResult.Draw){
          // transfer only BET_AMOUNT
          transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);

          // emit draw event
          emit DRAW(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
        }
        
      }

      // 결과를 확인 할 수 없는 경우(체크가 불가능한상태)
      // Not revealed(마이닝이 되지 않은 상황) ==> block.number <= AnswerBlockNumber
      if(currentBlockStatus == BlockStatus.NotRevealed){
        break;
      }

      // block limit passed : block.number >= AnswerBlockNumber + BLOCK_LIMIT(256)
      if(currentBlockStatus == BlockStatus.BlockLimitPassed){
        // 환불
          transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
        // emit refund event
          emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
      }

      popBet(cur);
      // check the answer
    }

    _head = cur;
  }

  function transferAfterPayingFee(address payable addr, uint256 amount) internal returns(uint256){
    // uint256 fee = amount / 100;
    uint256 fee = 0;  // test를 위해서 0
    uint256 amountWithoutFee = amount - fee;

    // transfer to addr
    addr.transfer(amountWithoutFee);

    // transfer to owner
    owner.transfer(fee);

    // 스마트컨트랙트 안에서 ether를 전송하는 3가지 방법
    // call, send, transfer(recommended)
    // transfer : 이더 전송에만 사용됨. 전송 실패시 트랜잭션 자체가 fail처리됨(가장 안전함)
    // send : 돈을 보내긴 하는데, boolean으로 결과를 리턴
    // call : 이더를 보내거나 외부의 다른 스마트컨트랙트의 특정 function 호출이 가능(주로 여기서 문제가 많이 발생 함. 외부꺼 호출하다 취약점 발생)

    return amountWithoutFee;
  }

  function setAnswerForTest(bytes32 answer) public returns (bool result) {
    require(msg.sender == owner, "Only owner can set the answer for test mode");
    answerForTest = answer;
    return true;
  }

  function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns(bytes32 answer){
    return mode ? blockhash(answerBlockNumber) : answerForTest;
  }

/**
 * @dev 베팅글자와 정답을 확인
 * @param challenges 베팅 글자
 * @param answer 블럭해쉬
 * @return 정답결과
 */
  function isMatch(byte challenges, bytes32 answer) public pure returns (BettingResult){
    // challenges : 0xab 라고 가정(사이즈는 1byte)
    // answer(block hash) : 0xab...... ff 32byte

    byte c1 = challenges;
    byte c2 = challenges;
    byte a1 = answer[0];
    byte a2 = answer[0];

    // get first number
    c1 = c1 >> 4;   // 0xab -> 0x0a
    c1 = c1 << 4;   // 0xab -> 0xa0

    a1 = a1 >> 4;
    a1 = a1 << 4;

    // get second number
    c2 = c2 << 4; // 0xab -> 0xb0
    c2 = c2 >> 4; // 0xb0 -> 0x0b

    a2 = a2 << 4;
    a2 = a2 >> 4;

    if(a1 == c1 && a2 == c2){
      return BettingResult.Win;
    }

    if(a1 == c1 || a2 == c2){
      return BettingResult.Draw;
    }

    return BettingResult.Fail;
  }

  function getBlockStatus(uint256 answerBlockNumber) internal view returns (BlockStatus) {
    if(block.number > answerBlockNumber && block.number < BLOCK_LIMIT + answerBlockNumber) {
      return BlockStatus.Checkable;
    }

    if(block.number <= answerBlockNumber){
      return BlockStatus.NotRevealed;
    }

    if(block.number >= answerBlockNumber + BLOCK_LIMIT){
      return BlockStatus.BlockLimitPassed;
    }

    return BlockStatus.BlockLimitPassed;
  }


  // 결과값 저장 및 분배
  function getBetInfo(uint256 index) public view returns(uint256 answerBlockNumber, address bettor, byte challenges){
    // returns에 선언된 변수 명을 그대로 쓰면 함수 호출 시 그게 바로 return 된다
    BetInfo memory b = _bets[index];
    answerBlockNumber = b.answerBlockNumber;
    bettor = b.bettor;
    challenges = b.challenges;
  }

  function pushBet(byte challenges) internal returns (bool){
    BetInfo memory b;
    b.bettor = msg.sender;  // 20 byte
    // block.number은 현재 트랜잭션이 들어갈 블럭 번호를 가져옴
    b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;  // 32 byte(uint256 이기 때문)
    b.challenges = challenges;  // byte

    _bets[_tail] = b;   // map에 저장하는 것은 gas 소모가 크지 않다
    _tail++;  // 32 byte(uint256 이기 때문)

    return true;
  }

  function popBet(uint256 index) internal returns (bool){
    // delete는 스마트컨트랙트에 데이터를 더이상 저장하지 않겠다는 의미
    // delete 를 사용 할 경우 가스를 돌려 받게 됨(가스비에 유리 할 듯)
    delete _bets[index];
    return true;
  }
}
