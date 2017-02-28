/*****************************************************************
This is a 6-hour hackaton experimental contract.
Not reviewed. Not tested. Do not use.
*****************************************************************/

pragma solidity ^0.4.4;

import "./Token.sol";

contract Event {

  // logs  ---------------------------------------------------
    
  event LogSignature(address indexed _signer);
  event LogChangeStatus(EventStatus _oldStatus, EventStatus _newStatus, address _user);

  // State machines  ----------------------------------------------
    
  enum EventStatus { Pending, Active, Pay, Paid, Refunding, PendingNotary }
  enum SignatureStatus { Pending, Done }
  enum ApprovalStatus { Pending, Pay, Refund }

  // modifiers -----------------------------------------------

  modifier onlyParticipants() {
    if (msg.sender != artist.addr && msg.sender != organizer.addr && msg.sender != auditorium.addr) throw;
    _;
  }

  modifier onlyNotary() {
    if (msg.sender != notary) throw;
    _;
  }

  modifier onlyBuyers() {
    if (!buyers[msg.sender].exists) throw;
    _;
  }

  modifier onlyAdmin() {
    if (msg.sender != notary) throw;
    _;
  }

  modifier assertStatus(EventStatus requieredStatus){
    if (eventStatus != requieredStatus) throw;
    _;
  }

  // construction parameters  -----------------------------------------------

  uint16  public eventNo;

  address public notary;
  address public factoryOwner;

  bytes32 public eventName;
  uint    public eventDate;
  uint256 public eventPrice;
  uint16  public totalTickets;
  uint256 public totalAmount;
    
  Token   bsToken;
  
  // state variables -----------------------------------------------

  struct Party {
    address         addr;
    SignatureStatus signatureStatus;
    ApprovalStatus  approvalStatus;
  }

  struct Buyer {
    bool    exists;
    bool    refunded;
    bool    claimed;
  }

  EventStatus public eventStatus;
  
  Party public artist;
  Party public organizer;
  Party public auditorium;

  uint16 public availableTickets;
  uint16 public claimedTickets;

  mapping (address => Buyer) buyers;

  // the code --------------------------------------------------------

  function Event(
    
    uint16  _eventNo,
    
    address _artist,
    address _organizer,
    address _auditorium,

    address _notary,
    address _factoryOwner,

    bytes32 _eventName,
    uint    _eventDate, 
    uint256 _eventPrice,
    uint16  _totalTickets

  ) {

    bsToken = Token(0xBAF280D5CDD14F40C997D92D15A3C9A48DDC88F3);

    eventNo = _eventNo;

    artist = Party ( {
        addr: _artist,
        signatureStatus: SignatureStatus.Pending,
        approvalStatus:  ApprovalStatus.Pending
    } );
    organizer = Party ( {
        addr: _organizer,
        signatureStatus: SignatureStatus.Pending,
        approvalStatus:  ApprovalStatus.Pending
    } );
    auditorium = Party ( {
        addr: _auditorium,
        signatureStatus: SignatureStatus.Pending,
        approvalStatus:  ApprovalStatus.Pending
    } );
        
    notary = _notary;
    factoryOwner = _factoryOwner;

    eventName = _eventName;
    eventDate = _eventDate;
    eventPrice = _eventPrice;
    totalTickets = _totalTickets;
    availableTickets = _totalTickets;

  }

  function sign()
  onlyParticipants()
  {
    if (msg.sender == artist.addr) {
      artist.signatureStatus = SignatureStatus.Done;
      LogSignature(artist.addr);
    } else
    if (msg.sender == organizer.addr) {
      organizer.signatureStatus = SignatureStatus.Done;
      LogSignature(organizer.addr);
    } else
    if (msg.sender == auditorium.addr) {
      auditorium.signatureStatus = SignatureStatus.Done;
      LogSignature(auditorium.addr);
    }
    
    if (artist.signatureStatus == SignatureStatus.Done
        && organizer.signatureStatus == SignatureStatus.Done
        && artist.signatureStatus  == SignatureStatus.Done )
    {
      changeStatus(EventStatus.Active);
    }

  }

  function changeStatus(EventStatus _status) internal {
    if ( (eventStatus == EventStatus.Pending && _status == EventStatus.Active ) 
         || (eventStatus == EventStatus.Active && _status == EventStatus.PendingNotary)
         || (eventStatus == EventStatus.Active && _status == EventStatus.Paid)
         || (eventStatus == EventStatus.PendingNotary && _status == EventStatus.Paid)
         || (eventStatus == EventStatus.Active && _status == EventStatus.Refunding)
         || (eventStatus == EventStatus.PendingNotary && _status == EventStatus.Refunding) )
    {
      LogChangeStatus(eventStatus, _status, msg.sender);
      eventStatus = _status;
      return;
    }
    throw;
  }

  function buyTicket()
  assertStatus(EventStatus.Active)
  {
      
    if (availableTickets == 0) {
      return;
    }

      address buyer = msg.sender;
      
    if (buyers[buyer].exists) {
      return;
    }

    bsToken.transferFrom(buyer,this,eventPrice);

        buyers[buyer].exists = true;

    availableTickets--;  
    
    totalAmount += eventPrice;

  }
  
  function doTransferToParticipants() internal {
      
    uint256 amountArtist = ( 45 * totalAmount ) / 100;
    uint256 amountOrganizer = ( 10 * totalAmount ) / 100;
    uint256 amountAuditorium = totalAmount - amountArtist - amountOrganizer;
        
    bsToken.transferFrom(this,artist.addr,amountArtist);
    bsToken.transferFrom(this,organizer.addr,amountOrganizer);
    bsToken.transferFrom(this,auditorium.addr,amountAuditorium);
      
  }

  function transferToParticipants()
  assertStatus(EventStatus.Pay)
  onlyParticipants()
  {
        if (now > eventDate + 1 days ) {
          doTransferToParticipants();
          changeStatus (EventStatus.Paid);
        }
  }
  
  function withdrawOnRefund()
  assertStatus(EventStatus.Refunding)
  onlyBuyers()
  {
      if (! buyers[msg.sender].refunded) {
          buyers[msg.sender].refunded = true;
            bsToken.transferFrom(this,msg.sender,eventPrice);
            return;
      }
  }

  function claim()
  assertStatus(EventStatus.Pay)
  onlyBuyers()
  {
      if (! buyers[msg.sender].claimed) {
        buyers[msg.sender].claimed = true;
   
        claimedTickets++;
        if (claimedTickets > (totalTickets - availableTickets) /2 ) {
          changeStatus (EventStatus.PendingNotary);
        }
        return;
      }
  }

  function hardResolve(bool _success)
  onlyNotary()
  {
      if (_success) {
         doTransferToParticipants();
         changeStatus (EventStatus.Paid);
      } else {
         changeStatus (EventStatus.Refunding);
      }
  }
  
  function resolve(bool _success)
  assertStatus(EventStatus.Active)
  onlyParticipants()
  {
      if (msg.sender == artist.addr && _success) {
            artist.approvalStatus = ApprovalStatus.Pay;        
      } else if (msg.sender == artist.addr && !_success) {
            artist.approvalStatus = ApprovalStatus.Refund;
      } else if (msg.sender == organizer.addr && _success) {
            organizer.approvalStatus = ApprovalStatus.Pay;
      } else if (msg.sender == organizer.addr && !_success) {
            organizer.approvalStatus = ApprovalStatus.Refund;
      } else if (msg.sender == auditorium.addr && _success) {
            auditorium.approvalStatus = ApprovalStatus.Pay;
      } else if (msg.sender == auditorium.addr && !_success) {
            auditorium.approvalStatus = ApprovalStatus.Refund;
      }
        
      if (artist.approvalStatus == organizer.approvalStatus
          && organizer.approvalStatus == auditorium.approvalStatus) {
              
          if (artist.approvalStatus == ApprovalStatus.Pay ) { 
            changeStatus(EventStatus.Pay);
          } else {
            changeStatus(EventStatus.Refunding);
          }
      }
   }

}