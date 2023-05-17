var sigs = {};

function addSig(sig) {
  var bytes4 = web3.sha3(sig).substring(0, 10);
  sigs[bytes4] = sig;
}

// From DSAuth
addSig("setOwner(address)");
addSig("setAuthority(address)");


var addressNames = {};
var nameAddresses = {};

function addAddressNames(address, name) {
  var a = address.toLowerCase();
  addressNames[a] = name;
  nameAddresses[name] = a;
}

function getAddressName(address) {
  if (address != null) {
    var a = address.toLowerCase();
    var n = addressNames[a];
    if (n !== undefined) {
      return n + ":" + address;
    }
  }
  return address;
}

function getShortAddressName(address) {
  if (address != null) {
    var a = address.toLowerCase();
    var n = addressNames[a];
    if (n !== undefined) {
      return n + ":" + address.substring(0, 6);
    }
  }
  return address;
}

function getNameFromAddress(address) {
  var a = address.toLowerCase();
  var n = addressNames[a];
  if (n !== undefined) {
    return address;
  } else {
    return "";
  }
}

function getAddressFromName(name) {
  var a = nameAddresses[name];
  if (a !== undefined) {
    return a;
  } else {
    return "";
  }
}


var addressSymbol = {};
var symbolAddresses = {};

function addAddressSymbol(address, symbol) {
  var a = address.toLowerCase();
  addressSymbol[a] = symbol;
  symbolAddresses[symbol] = a;
}

function getAddressSymbol(address) {
  if (address != null) {
    var a = address.toLowerCase();
    var s = addressSymbol[a];
    if (s !== undefined) {
      return s;
    }
  }
  return address;
}
