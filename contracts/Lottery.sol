pragma solidity >=0.4.21 < 0.6.0;

contract Lottery{
  struct BetInfo {
    uint256 answerBlockNumber;
    address payable bettor;     // 코인 전송을 위해서는 변수 앞에 payable을 써줘야함
    byte challenges;    // ex:0xab
  }

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
    b.bettor = msg.sender;
    // block.number은 현재 트랜잭션이 들어갈 블럭 번호를 가져옴
    b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;
    b.challenges = challenges;

    _bets[_tail] = b;
    _tail++;

    return true;
  }

  function popBet(uint256 index) internal returns (bool){
    // delete는 스마트컨트랙트에 데이터를 더이상 저장하지 않겠다는 의미
    // delete 를 사용 할 경우 가스를 돌려 받게 됨(가스비에 유리 할 듯)
    delete _bets[index];
    return true;
  }
}
