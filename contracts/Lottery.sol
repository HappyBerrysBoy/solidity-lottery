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
  address public owner;
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

  event BET(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);

  constructor() public {
    owner = msg.sender;
  }

  // view는 smartcontract에 저장된 값에 접근 시 사용
  // pure는 컨트랙 접근 없이 사용 가능함 함수
  function getPot() public view returns(uint256 pot){
    return _pot;
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
  function distribute() public {
    // 큐에 저장된 베팅 정보가 (head)3, 4, 5, 6, 7, 8, 9, 10(tail)
    // 큐 순서대로 값들을 체크하고, 2자리 모두 맞힌 경우 팟머니를 전송,
    // 1자리만 맞힌 경우 건 값만 돌려줌
    uint256 cur;
    BetInfo memory b;
    BlockStatus currentBlockStatus;

    for(cur=_head; cur<_tail; cur++){
      b = _bets[cur];
      currentBlockStatus = getBlockStatus(b.answerBlockNumber);
      
      // checkable : 블럭 넘버가 정답 블럭보다 커야하고, 블럭.number < BLOCK_LIMIT(256) + AnswerBlockNumber 
      if(currentBlockStatus == BlockStatus.Checkable){
        // if win, bettor gets pot

        // if fail, bettor's money goes pot

        // if draw, refund bettor's money
        
      }

      // 결과를 확인 할 수 없는 경우(체크가 불가능한상태)
      // Not revealed(마이닝이 되지 않은 상황) ==> block.number <= AnswerBlockNumber
      if(currentBlockStatus == BlockStatus.NotRevealed){
        break;
      }

      // block limit passed : block.number >= AnswerBlockNumber + BLOCK_LIMIT(256)
      if(currentBlockStatus == BlockStatus.BlockLimitPassed){
        // 환불
        // emit refund event
      }

      popBet(cur);
      // check the answer
    }
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
