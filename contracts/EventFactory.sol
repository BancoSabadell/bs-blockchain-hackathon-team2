/*****************************************************************
This is a 6-hour hackaton experimental contract.
Not reviewed. Not tested. Do not use.
*****************************************************************/

pragma solidity ^0.4.4;

import "./Event.sol";

contract EventFactory {

  uint16 eventNo;
  address owner;
  Event[] events;

  modifier onlyOwner() {
    if ( owner != msg.sender ) throw;
    _;
  }

  function EventFactory() {
    owner = msg.sender;
  }

  function createEvent(  
    address _artist,
    address _organizer,
    address _auditorium,

    address _notary,

    bytes32 _eventName,
    uint    _eventDate, // TODO: revisar
    uint256 _eventPrice,
    uint16  _totalTickets

    ) {

      eventNo++;

      Event evt = new Event(
        eventNo,
        
        _artist,
        _organizer,
        _auditorium,
        
        _notary,
        
        owner,
        _eventName,
        _eventDate,
        _eventPrice,
        _totalTickets
      );

      events.push(evt);

  }
  
  function getEvent(uint eventNo) constant returns (address) {
      return events[eventNo];
  }
  
  function getEventCount() constant returns (uint) {
      return events.length;
  }

}



